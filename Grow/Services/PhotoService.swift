import Foundation
import Observation
import SwiftData
import UIKit
import Vision

enum AlignmentSource: String, Codable, Equatable {
    case visionTranslation
    case fallbackEstimate
    case prototype
}

struct CaptureAlignment: Codable, Equatable {
    let score: Double
    let xOffset: Double
    let yOffset: Double
    let rotationDegrees: Double
    let source: AlignmentSource

    init(
        score: Double,
        xOffset: Double,
        yOffset: Double,
        rotationDegrees: Double,
        source: AlignmentSource = .fallbackEstimate
    ) {
        self.score = score
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.rotationDegrees = rotationDegrees
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case score
        case xOffset
        case yOffset
        case rotationDegrees
        case source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        score = try container.decode(Double.self, forKey: .score)
        xOffset = try container.decode(Double.self, forKey: .xOffset)
        yOffset = try container.decode(Double.self, forKey: .yOffset)
        rotationDegrees = try container.decode(Double.self, forKey: .rotationDegrees)
        source = try container.decodeIfPresent(AlignmentSource.self, forKey: .source) ?? .fallbackEstimate
    }

    var percent: Int { Int((score * 100).rounded()) }

    var adjective: String {
        switch score {
        case 0.97...: "buttery"
        case 0.93...: "steady"
        case 0.88...: "close"
        default: "needs a nudge"
        }
    }

    var sourceLabel: String {
        switch source {
        case .visionTranslation: "Vision matched"
        case .fallbackEstimate: "Estimated match"
        case .prototype: "Simulator match"
        }
    }

    var guidanceCopy: String {
        switch source {
        case .visionTranslation: "Frame locked from the previous photo"
        case .fallbackEstimate: "Saved with a steady-angle estimate"
        case .prototype: "Simulator frame saved for QA"
        }
    }
}

struct CaptureReward: Identifiable, Equatable {
    let id = UUID()
    let photoID: UUID
    let capturedAt: Date
    let dayIndex: Int
    let frameCount: Int
    let targetFrameCount: Int
    let alignment: CaptureAlignment
    let modeledProgressBefore: Double
    let modeledProgressAfter: Double
    let expectedStage: GrowStage
    let streak: StreakUpdate

    var futureReelProgress: Double {
        CaptureRewardPolicy.futureReelProgress(frameCount: frameCount, targetFrameCount: targetFrameCount)
    }

    var dayTitle: String { "Day \(dayIndex)" }

    var milestoneTitle: String? {
        CaptureRewardPolicy.milestoneTitle(dayIndex: dayIndex)
    }

    var firstWeekNote: String? {
        CaptureRewardPolicy.firstWeekNote(dayIndex: dayIndex)
    }
}

nonisolated class PhotoThumbnailEncoder {
    @MainActor
    func data(from image: UIImage) throws -> Data {
        let maxSide: CGFloat = 420
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, maxSide / max(1, longestSide))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = thumbnail.jpegData(compressionQuality: 0.76) else {
            throw PhotoServiceError.unableToCreateThumbnail
        }
        return data
    }
}

nonisolated class PhotoContextSaver {
    @MainActor
    func save(_ context: ModelContext) throws {
        try context.save()
    }
}

nonisolated final class PhotoService: Observable {
    private let context: ModelContext
    private let streakService: StreakService
    private let demoLibrary: DemoGrowPhotoLibrary?
    private let contextSaver: PhotoContextSaver
    private let thumbnailEncoder: PhotoThumbnailEncoder
    private let encoder = JSONEncoder()
    private let calendar: Calendar

    @MainActor
    init(
        context: ModelContext,
        streakService: StreakService,
        calendar: Calendar = .current,
        demoLibrary: DemoGrowPhotoLibrary? = nil,
        thumbnailEncoder: PhotoThumbnailEncoder? = nil,
        contextSaver: PhotoContextSaver? = nil
    ) {
        self.context = context
        self.streakService = streakService
        self.calendar = calendar
        self.demoLibrary = demoLibrary
        self.thumbnailEncoder = thumbnailEncoder ?? PhotoThumbnailEncoder()
        self.contextSaver = contextSaver ?? PhotoContextSaver()
    }

    @discardableResult
    @MainActor
    func recordCapture(
        imageData: Data,
        origin: GrowPhotoOrigin,
        for grow: Grow,
        species: PlantSpecies?
    ) throws -> CaptureReward {
        guard origin != .demoSample else {
            throw PhotoServiceError.invalidCaptureOrigin
        }
        return try persistCapture(
            imageData: imageData,
            origin: origin,
            sourceSampleID: nil,
            capturedAt: .now,
            grow: grow,
            species: species,
            alignment: nil
        )
    }

    @discardableResult
    @MainActor
    func recordDemoCapture(
        for grow: Grow,
        species: PlantSpecies?,
        capturedAt: Date = .now
    ) async throws -> CaptureReward {
        guard let demoLibrary else {
            throw PhotoServiceError.demoLibraryUnavailable
        }
        let existingPhotos = sortedPhotos(for: grow)
        let frameCount = existingPhotos.count + 1
        let dayIndex = max(growDayIndex(for: grow, at: capturedAt), frameCount)
        let asset = try demoLibrary.asset(forDay: dayIndex)
        return try persistCapture(
            imageData: asset.data,
            origin: .demoSample,
            sourceSampleID: asset.frame.id,
            capturedAt: capturedAt,
            grow: grow,
            species: species,
            alignment: prototypeAlignment(frameCount: frameCount)
        )
    }

    @MainActor
    private func persistCapture(
        imageData: Data,
        origin: GrowPhotoOrigin,
        sourceSampleID: String?,
        capturedAt: Date,
        grow: Grow,
        species: PlantSpecies?,
        alignment suppliedAlignment: CaptureAlignment?
    ) throws -> CaptureReward {
        let image = try normalizedImage(from: imageData)
        let fullSizeData = origin == .demoSample
            ? imageData
            : try encodedPhotoData(from: image)
        let thumbnailData = try thumbnailEncoder.data(from: image)
        let existingPhotos = sortedPhotos(for: grow)
        let frameCount = existingPhotos.count + 1
        let dayIndex = max(growDayIndex(for: grow, at: capturedAt), frameCount)
        let progressBefore = ModeledGrowthCurve.progress(dayIndex: max(1, dayIndex - 1), species: species)
        let progressAfter = ModeledGrowthCurve.progress(dayIndex: dayIndex, species: species)
        let stage = ModeledGrowthCurve.stage(for: progressAfter)
        let alignment = suppliedAlignment ?? alignmentForCapture(
            image,
            previousPhoto: existingPhotos.last,
            fallbackFrameCount: frameCount
        )
        let alignmentData = try encoder.encode(alignment)

        let photo = GrowPhoto(capturedAt: capturedAt, dayIndex: dayIndex, stage: stage)
        let localFileName = "Photos/\(grow.id.uuidString)/\(photo.id.uuidString).jpg"
        try writePhoto(fullSizeData, localFileName: localFileName)
        photo.localFileName = localFileName
        photo.thumbnailData = thumbnailData
        photo.alignmentData = alignmentData
        photo.caption = CaptureRewardPolicy.caption(dayIndex: dayIndex, alignment: alignment)
        photo.isMilestone = CaptureRewardPolicy.milestoneTitle(dayIndex: dayIndex) != nil
        photo.origin = origin
        photo.sourceSampleID = sourceSampleID
        photo.grow = grow
        context.insert(photo)

        let previousCoverPhotoID = grow.coverPhotoID
        let previousStage = grow.currentStage
        if grow.coverPhotoID == nil {
            grow.coverPhotoID = photo.id
        }
        grow.currentStage = stage
        let streakTransaction = streakService.stageCapture(at: capturedAt)

        do {
            try save()
        } catch {
            streakTransaction.rollback()
            rollbackCapture(
                photo,
                localFileName: localFileName,
                grow: grow,
                previousCoverPhotoID: previousCoverPhotoID,
                previousStage: previousStage
            )
            throw error
        }

        return CaptureReward(
            photoID: photo.id,
            capturedAt: capturedAt,
            dayIndex: dayIndex,
            frameCount: frameCount,
            targetFrameCount: 30,
            alignment: alignment,
            modeledProgressBefore: progressBefore,
            modeledProgressAfter: progressAfter,
            expectedStage: stage,
            streak: streakTransaction.update
        )
    }

    @MainActor
    private func sortedPhotos(for grow: Grow) -> [GrowPhoto] {
        (grow.photos ?? []).sorted { lhs, rhs in
            if lhs.dayIndex != rhs.dayIndex { return lhs.dayIndex < rhs.dayIndex }
            if lhs.capturedAt != rhs.capturedAt { return lhs.capturedAt < rhs.capturedAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    @MainActor
    private func growDayIndex(for grow: Grow, at date: Date) -> Int {
        let start = calendar.startOfDay(for: grow.startDate)
        let capture = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: capture).day ?? 0
        return max(1, days + 1)
    }

    @MainActor
    private func prototypeAlignment(frameCount: Int) -> CaptureAlignment {
        estimatedAlignment(frameCount: frameCount, source: .prototype)
    }

    @MainActor
    private func estimatedAlignment(frameCount: Int, source: AlignmentSource) -> CaptureAlignment {
        let cycle = Double((frameCount * 7) % 12)
        let score = min(0.99, 0.88 + cycle / 100)
        return CaptureAlignment(
            score: score,
            xOffset: Double((frameCount % 5) - 2) * 0.012,
            yOffset: Double(((frameCount + 2) % 5) - 2) * 0.01,
            rotationDegrees: Double((frameCount % 7) - 3) * 0.15,
            source: source
        )
    }

    @MainActor
    private func alignmentForCapture(_ image: UIImage, previousPhoto: GrowPhoto?, fallbackFrameCount: Int) -> CaptureAlignment {
        guard
            let previousPhoto,
            !previousPhoto.localFileName.isEmpty,
            let previousImage = UIImage(contentsOfFile: photoURL(for: previousPhoto.localFileName).path),
            let currentCGImage = image.cgImage,
            let previousCGImage = previousImage.cgImage
        else {
            return estimatedAlignment(frameCount: fallbackFrameCount, source: .fallbackEstimate)
        }

        let request = VNTranslationalImageRegistrationRequest(
            targetedCGImage: previousCGImage,
            orientation: .up,
            options: [:]
        )
        let handler = VNImageRequestHandler(cgImage: currentCGImage, orientation: .up, options: [:])

        do {
            try handler.perform([request])
            guard let observation = request.results?.first else {
                return estimatedAlignment(frameCount: fallbackFrameCount, source: .fallbackEstimate)
            }

            let transform = observation.alignmentTransform
            let normalizedX = Double(transform.tx) / Double(max(1, previousCGImage.width))
            let normalizedY = Double(transform.ty) / Double(max(1, previousCGImage.height))
            let drift = hypot(normalizedX, normalizedY)
            let score = max(0.62, min(0.99, 1 - drift * 5.5))

            return CaptureAlignment(
                score: score,
                xOffset: normalizedX,
                yOffset: normalizedY,
                rotationDegrees: 0,
                source: .visionTranslation
            )
        } catch {
            return estimatedAlignment(frameCount: fallbackFrameCount, source: .fallbackEstimate)
        }
    }

    @MainActor
    private func normalizedImage(from data: Data) throws -> UIImage {
        guard let source = UIImage(data: data) else {
            throw PhotoServiceError.unreadableImage
        }

        guard source.imageOrientation != .up else {
            return source
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = source.scale
        let renderer = UIGraphicsImageRenderer(size: source.size, format: format)
        return renderer.image { _ in
            source.draw(in: CGRect(origin: .zero, size: source.size))
        }
    }

    @MainActor
    private func encodedPhotoData(from image: UIImage) throws -> Data {
        guard let data = image.jpegData(compressionQuality: 0.92) else {
            throw PhotoServiceError.unableToEncodeImage
        }
        return data
    }

    @MainActor
    private func writePhoto(_ data: Data, localFileName: String) throws {
        let url = photoURL(for: localFileName)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic])
    }

    @MainActor
    private func photoURL(for localFileName: String) -> URL {
        AppGroup.containerURL.appendingPathComponent(localFileName)
    }

    @MainActor
    private func rollbackCapture(
        _ photo: GrowPhoto,
        localFileName: String,
        grow: Grow,
        previousCoverPhotoID: UUID?,
        previousStage: GrowStage
    ) {
        try? FileManager.default.removeItem(at: photoURL(for: localFileName))
        grow.photos?.removeAll { $0.id == photo.id }
        context.delete(photo)
        grow.coverPhotoID = previousCoverPhotoID
        grow.currentStage = previousStage
    }

    @MainActor
    private func save() throws {
        do {
            try contextSaver.save(context)
        } catch {
            #if DEBUG
            print("Grow: photo save failed: \(error)")
            #endif
            throw PhotoServiceError.metadataSaveFailed
        }
    }
}

enum PhotoServiceError: LocalizedError, Equatable {
    case unreadableImage
    case unableToEncodeImage
    case unableToCreateThumbnail
    case metadataSaveFailed
    case invalidCaptureOrigin
    case demoLibraryUnavailable

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            "Grow could not read that plant photo."
        case .unableToEncodeImage:
            "Grow could not prepare that photo for your timeline."
        case .unableToCreateThumbnail:
            "Grow could not prepare the timeline preview for that photo."
        case .metadataSaveFailed:
            "Grow could not save that growth memory. Please try again."
        case .invalidCaptureOrigin:
            "That photo source cannot be saved through this capture path."
        case .demoLibraryUnavailable:
            "Grow could not load the sample photo story."
        }
    }
}
