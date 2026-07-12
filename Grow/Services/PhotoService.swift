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

@Observable
final class PhotoService {
    private let context: ModelContext
    private let streakService: StreakService
    private let saveContext: (ModelContext) throws -> Void
    private let encoder = JSONEncoder()
    private let calendar: Calendar

    init(
        context: ModelContext,
        streakService: StreakService,
        calendar: Calendar = .current,
        saveContext: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.context = context
        self.streakService = streakService
        self.calendar = calendar
        self.saveContext = saveContext
    }

    @discardableResult
    func recordCapture(imageData: Data, for grow: Grow, species: PlantSpecies?) throws -> CaptureReward {
        let image = try normalizedImage(from: imageData)
        let fullSizeData = try encodedPhotoData(from: image)
        let existingPhotos = sortedPhotos(for: grow)
        let frameCount = existingPhotos.count + 1
        let capturedAt = Date()
        let dayIndex = max(growDayIndex(for: grow, at: capturedAt), frameCount)
        let progressBefore = ModeledGrowthCurve.progress(dayIndex: max(1, dayIndex - 1), species: species)
        let progressAfter = ModeledGrowthCurve.progress(dayIndex: dayIndex, species: species)
        let stage = ModeledGrowthCurve.stage(for: progressAfter)
        let alignment = alignmentForCapture(image, previousPhoto: existingPhotos.last, fallbackFrameCount: frameCount)

        let photo = GrowPhoto(capturedAt: capturedAt, dayIndex: dayIndex, stage: stage)
        let localFileName = "Photos/\(grow.id.uuidString)/\(photo.id.uuidString).jpg"
        try writePhoto(fullSizeData, localFileName: localFileName)
        photo.localFileName = localFileName
        photo.thumbnailData = thumbnailData(from: image)
        photo.alignmentData = try? encoder.encode(alignment)
        photo.caption = CaptureRewardPolicy.caption(dayIndex: dayIndex, alignment: alignment)
        photo.isMilestone = CaptureReward(
            photoID: photo.id,
            capturedAt: capturedAt,
            dayIndex: dayIndex,
            frameCount: frameCount,
            targetFrameCount: 30,
            alignment: alignment,
            modeledProgressBefore: progressBefore,
            modeledProgressAfter: progressAfter,
            expectedStage: stage,
            streak: streakService.snapshot()
        ).milestoneTitle != nil
        photo.grow = grow
        context.insert(photo)

        let previousCoverPhotoID = grow.coverPhotoID
        let previousStage = grow.currentStage
        if grow.coverPhotoID == nil {
            grow.coverPhotoID = photo.id
        }
        grow.currentStage = stage

        do {
            try save()
        } catch {
            rollbackCapture(
                photo,
                localFileName: localFileName,
                grow: grow,
                previousCoverPhotoID: previousCoverPhotoID,
                previousStage: previousStage
            )
            throw error
        }

        let streak = streakService.recordCapture(at: capturedAt)

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
            streak: streak
        )
    }

    /// Prototype capture used until the AVFoundation camera lands. It records durable
    /// photo metadata, alignment JSON, streak progress, and the exact reward payload the
    /// real camera flow will emit.
    @discardableResult
    func recordPrototypeCapture(for grow: Grow, species: PlantSpecies?, capturedAt: Date = Date()) -> CaptureReward {
        let existingPhotos = sortedPhotos(for: grow)
        let frameCount = existingPhotos.count + 1
        let dayIndex = max(growDayIndex(for: grow, at: capturedAt), frameCount)
        let progressBefore = ModeledGrowthCurve.progress(dayIndex: max(1, dayIndex - 1), species: species)
        let progressAfter = ModeledGrowthCurve.progress(dayIndex: dayIndex, species: species)
        let stage = ModeledGrowthCurve.stage(for: progressAfter)
        let alignment = prototypeAlignment(frameCount: frameCount)

        let photo = GrowPhoto(capturedAt: capturedAt, dayIndex: dayIndex, stage: stage)
        let prototypeFrame = prototypeImage(
            frameCount: frameCount,
            progress: progressAfter
        )
        let localFileName = "Photos/\(grow.id.uuidString)/\(photo.id.uuidString).jpg"
        do {
            let frameData = try encodedPhotoData(from: prototypeFrame)
            try writePhoto(frameData, localFileName: localFileName)
            photo.localFileName = localFileName
            photo.thumbnailData = thumbnailData(from: prototypeFrame)
        } catch {
            #if DEBUG
            print("Grow: prototype frame write failed: \(error)")
            #endif
        }
        photo.alignmentData = try? encoder.encode(alignment)
        photo.caption = CaptureRewardPolicy.caption(dayIndex: dayIndex, alignment: alignment)
        photo.isMilestone = CaptureReward(
            photoID: photo.id,
            capturedAt: capturedAt,
            dayIndex: dayIndex,
            frameCount: frameCount,
            targetFrameCount: 30,
            alignment: alignment,
            modeledProgressBefore: progressBefore,
            modeledProgressAfter: progressAfter,
            expectedStage: stage,
            streak: streakService.snapshot()
        ).milestoneTitle != nil
        photo.grow = grow
        context.insert(photo)

        if grow.coverPhotoID == nil {
            grow.coverPhotoID = photo.id
        }
        grow.currentStage = stage

        let streak = streakService.recordCapture(at: capturedAt)
        try? save()

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
            streak: streak
        )
    }

    private func sortedPhotos(for grow: Grow) -> [GrowPhoto] {
        (grow.photos ?? []).sorted { $0.capturedAt < $1.capturedAt }
    }

    private func growDayIndex(for grow: Grow, at date: Date) -> Int {
        let start = calendar.startOfDay(for: grow.startDate)
        let capture = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: capture).day ?? 0
        return max(1, days + 1)
    }

    private func prototypeAlignment(frameCount: Int) -> CaptureAlignment {
        estimatedAlignment(frameCount: frameCount, source: .prototype)
    }

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

    private func prototypeImage(frameCount: Int, progress: Double) -> UIImage {
        let size = CGSize(width: 1080, height: 1920)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let context = renderer.cgContext
            let bounds = CGRect(origin: .zero, size: size)
            UIColor(hex: 0xF6EEDC).setFill()
            context.fill(bounds)

            context.saveGState()
            context.setStrokeColor(UIColor(hex: 0xDDD3C0).withAlphaComponent(0.42).cgColor)
            context.setLineWidth(2)
            for x in stride(from: CGFloat(88), through: size.width - 88, by: 118) {
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x + 52, y: size.height))
                context.strokePath()
            }
            context.restoreGState()

            let glowCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.28)
            let glowRect = CGRect(x: glowCenter.x - 470, y: glowCenter.y - 470, width: 940, height: 940)
            UIColor(hex: 0xFFCB73).withAlphaComponent(0.28).setFill()
            context.fillEllipse(in: glowRect)

            let jarRect = CGRect(x: 210, y: 610, width: 660, height: 890)
            let jarPath = UIBezierPath(roundedRect: jarRect, cornerRadius: 140)
            UIColor.white.withAlphaComponent(0.38).setFill()
            jarPath.fill()
            UIColor(hex: 0xC9D8C0).withAlphaComponent(0.82).setStroke()
            jarPath.lineWidth = 6
            jarPath.stroke()

            let waterRect = CGRect(x: jarRect.minX + 32, y: jarRect.maxY - 280, width: jarRect.width - 64, height: 222)
            let waterPath = UIBezierPath(roundedRect: waterRect, cornerRadius: 92)
            UIColor(hex: 0x4E9DB0).withAlphaComponent(0.23).setFill()
            waterPath.fill()

            drawPrototypePebbles(in: context, jarRect: jarRect, frameCount: frameCount)
            drawPrototypePlant(in: context, jarRect: jarRect, progress: progress, frameCount: frameCount)
        }
    }

    private func drawPrototypePlant(in context: CGContext, jarRect: CGRect, progress: Double, frameCount: Int) {
        let p = CGFloat(min(1, max(0.06, progress)))
        let base = CGPoint(x: jarRect.midX, y: jarRect.maxY - 175)
        let tip = CGPoint(x: jarRect.midX + CGFloat((frameCount % 5) - 2) * 8, y: jarRect.maxY - 230 - jarRect.height * 0.58 * p)
        let stem = UIBezierPath()
        stem.move(to: base)
        stem.addCurve(
            to: tip,
            controlPoint1: CGPoint(x: base.x - 74, y: base.y - 260 * p),
            controlPoint2: CGPoint(x: tip.x + 70, y: tip.y + 190 * p)
        )
        UIColor(hex: 0x2C7C3C).setStroke()
        stem.lineWidth = 12 + p * 10
        stem.lineCapStyle = .round
        stem.stroke()

        let pairCount = max(1, Int((p * 5).rounded()))
        for index in 0..<pairCount {
            let t = CGFloat(index + 1) / CGFloat(pairCount + 1)
            let y = base.y + (tip.y - base.y) * t
            let x = base.x + sin(t * .pi * 1.3) * 42
            let attach = CGPoint(x: x, y: y)
            let length = 126 * (1 - t * 0.26) * (0.72 + p * 0.34)
            drawPrototypeLeaf(at: attach, length: length, angle: -.pi * 0.88, color: UIColor(hex: 0x3E9E4F))
            drawPrototypeLeaf(at: attach, length: length, angle: -.pi * 0.12, color: UIColor(hex: 0x8DCB7C))
        }

        if progress > 0.68 {
            UIColor(hex: 0xF0A04A).setFill()
            for petal in 0..<6 {
                let angle = CGFloat(petal) / 6 * .pi * 2
                let rect = CGRect(
                    x: tip.x + cos(angle) * 44 - 27,
                    y: tip.y + sin(angle) * 44 - 27,
                    width: 54,
                    height: 54
                )
                context.fillEllipse(in: rect)
            }
            UIColor(hex: 0xFFCB73).setFill()
            context.fillEllipse(in: CGRect(x: tip.x - 22, y: tip.y - 22, width: 44, height: 44))
        }
    }

    private func drawPrototypeLeaf(at point: CGPoint, length: CGFloat, angle: CGFloat, color: UIColor) {
        let tip = CGPoint(x: point.x + cos(angle) * length, y: point.y + sin(angle) * length)
        let mid = CGPoint(x: (point.x + tip.x) / 2, y: (point.y + tip.y) / 2)
        let normal = CGPoint(x: -sin(angle), y: cos(angle))
        let width = length * 0.36
        let leaf = UIBezierPath()
        leaf.move(to: point)
        leaf.addQuadCurve(to: tip, controlPoint: CGPoint(x: mid.x + normal.x * width, y: mid.y + normal.y * width))
        leaf.addQuadCurve(to: point, controlPoint: CGPoint(x: mid.x - normal.x * width, y: mid.y - normal.y * width))
        color.setFill()
        leaf.fill()

        UIColor(hex: 0x16431F).withAlphaComponent(0.25).setStroke()
        let vein = UIBezierPath()
        vein.move(to: point)
        vein.addLine(to: tip)
        vein.lineWidth = 2
        vein.stroke()
    }

    private func drawPrototypePebbles(in context: CGContext, jarRect: CGRect, frameCount: Int) {
        let colors = [UIColor(hex: 0xD48A45), UIColor(hex: 0xF0A04A), UIColor(hex: 0xB66A32)]
        for index in 0..<15 {
            let seed = CGFloat((index * 37 + frameCount * 13) % 100) / 100
            let diameter = CGFloat(34 + (index * 11) % 30)
            let x = jarRect.minX + 72 + CGFloat((index * 83) % 520)
            let y = jarRect.maxY - 126 - seed * 92
            colors[index % colors.count].withAlphaComponent(0.86).setFill()
            context.fillEllipse(in: CGRect(x: x, y: y, width: diameter, height: diameter))
        }
    }

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

    private func encodedPhotoData(from image: UIImage) throws -> Data {
        guard let data = image.jpegData(compressionQuality: 0.92) else {
            throw PhotoServiceError.unableToEncodeImage
        }
        return data
    }

    private func thumbnailData(from image: UIImage) -> Data? {
        let maxSide: CGFloat = 420
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, maxSide / max(1, longestSide))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return thumbnail.jpegData(compressionQuality: 0.76)
    }

    private func writePhoto(_ data: Data, localFileName: String) throws {
        let url = photoURL(for: localFileName)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic])
    }

    private func photoURL(for localFileName: String) -> URL {
        AppGroup.containerURL.appendingPathComponent(localFileName)
    }

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

    private func save() throws {
        do {
            try saveContext(context)
        } catch {
            #if DEBUG
            print("Grow: photo save failed: \(error)")
            #endif
            throw PhotoServiceError.metadataSaveFailed
        }
    }
}

private extension UIColor {
    convenience init(hex value: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha
        )
    }
}

enum PhotoServiceError: LocalizedError {
    case unreadableImage
    case unableToEncodeImage
    case metadataSaveFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            "Grow could not read that plant photo."
        case .unableToEncodeImage:
            "Grow could not prepare that photo for your timeline."
        case .metadataSaveFailed:
            "Grow could not save that growth memory. Please try again."
        }
    }
}
