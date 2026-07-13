import CoreGraphics
import Foundation

enum GrowPhotoResolutionPolicy: Equatable, Sendable {
    case genuineMediaOnly
    case demoAllowed
    case interactiveRecoveryAllowed(day: Int)
}

struct ResolvedImage: @unchecked Sendable {
    let cgImage: CGImage
}

struct ResolvedGrowPhoto: Sendable {
    let image: ResolvedImage
    let provenance: GrowPhotoProvenance
    let quality: GrowPhotoQuality
    let sampleID: String?
}

enum GrowPhotoResolutionError: LocalizedError, Equatable {
    case missingGenuineMedia
    case policyViolation
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .missingGenuineMedia:
            "The original grow photo is unavailable."
        case .policyViolation:
            "This photo source is not allowed in the current context."
        case .decodeFailed:
            "Grow could not decode this photo."
        }
    }
}

struct GrowPhotoSourceResolver {
    typealias FullSizeDataLoader = @Sendable (String) async throws -> Data?
    typealias DemoAssetByIDLoader = @Sendable (String) async throws -> DemoGrowPhotoAsset?
    typealias DemoAssetForDayLoader = @Sendable (Int) async throws -> DemoGrowPhotoAsset?

    private let decoder: GrowImageDecoder
    private let fullSizeData: FullSizeDataLoader
    private let demoAssetByID: DemoAssetByIDLoader
    private let demoAssetForDay: DemoAssetForDayLoader

    init(
        decoder: GrowImageDecoder,
        fullSizeData: @escaping FullSizeDataLoader,
        demoAssetByID: @escaping DemoAssetByIDLoader,
        demoAssetForDay: @escaping DemoAssetForDayLoader
    ) {
        self.decoder = decoder
        self.fullSizeData = fullSizeData
        self.demoAssetByID = demoAssetByID
        self.demoAssetForDay = demoAssetForDay
    }

    func resolve(
        photo: GrowPhoto,
        policy: GrowPhotoResolutionPolicy,
        targetMaxPixel: Int
    ) async throws -> ResolvedGrowPhoto {
        try Task.checkCancellation()

        if photo.origin == .demoSample, policy != .demoAllowed {
            throw GrowPhotoResolutionError.policyViolation
        }

        let storedProvenance = try provenance(for: photo)
        if !photo.localFileName.isEmpty,
           let data = try await fullSizeData(photo.localFileName),
           let image = try await decodeIfPossible(
               data,
               maxPixelSize: targetMaxPixel,
               sourceID: "full:\(photo.id.uuidString):\(photo.localFileName)"
           ) {
            return ResolvedGrowPhoto(
                image: ResolvedImage(cgImage: image),
                provenance: storedProvenance,
                quality: .fullSize,
                sampleID: photo.sourceSampleID
            )
        }

        try Task.checkCancellation()
        if let thumbnailData = photo.thumbnailData,
           let image = try await decodeIfPossible(
               thumbnailData,
               maxPixelSize: targetMaxPixel,
               sourceID: "thumbnail:\(photo.id.uuidString)"
           ) {
            return ResolvedGrowPhoto(
                image: ResolvedImage(cgImage: image),
                provenance: storedProvenance,
                quality: .thumbnail,
                sampleID: photo.sourceSampleID
            )
        }

        try Task.checkCancellation()
        switch (photo.origin, policy) {
        case (.demoSample, .demoAllowed):
            guard let sampleID = photo.sourceSampleID else {
                throw GrowPhotoResolutionError.policyViolation
            }
            guard let asset = try await demoAssetByID(sampleID) else {
                throw GrowPhotoResolutionError.decodeFailed
            }
            let image = try await decodeRequired(
                asset.data,
                maxPixelSize: targetMaxPixel,
                sourceID: "demo:\(sampleID)"
            )
            return ResolvedGrowPhoto(
                image: ResolvedImage(cgImage: image),
                provenance: .demoSample(sampleID: sampleID),
                quality: .fullSize,
                sampleID: sampleID
            )

        case (.legacyUserMedia, .interactiveRecoveryAllowed(let day)),
             (.camera, .interactiveRecoveryAllowed(let day)),
             (.photoLibrary, .interactiveRecoveryAllowed(let day)):
            guard let asset = try await demoAssetForDay(day) else {
                throw GrowPhotoResolutionError.decodeFailed
            }
            let image = try await decodeRequired(
                asset.data,
                maxPixelSize: targetMaxPixel,
                sourceID: "recovery:\(asset.frame.id)"
            )
            return ResolvedGrowPhoto(
                image: ResolvedImage(cgImage: image),
                provenance: .recoverySample(sampleID: asset.frame.id),
                quality: .fallback,
                sampleID: asset.frame.id
            )

        case (.legacyUserMedia, .genuineMediaOnly),
             (.camera, .genuineMediaOnly),
             (.photoLibrary, .genuineMediaOnly):
            throw GrowPhotoResolutionError.missingGenuineMedia

        case (.legacyUserMedia, .demoAllowed),
             (.camera, .demoAllowed),
             (.photoLibrary, .demoAllowed),
             (.demoSample, .genuineMediaOnly),
             (.demoSample, .interactiveRecoveryAllowed):
            throw GrowPhotoResolutionError.policyViolation
        }
    }

    private func provenance(for photo: GrowPhoto) throws -> GrowPhotoProvenance {
        switch photo.origin {
        case .legacyUserMedia:
            .legacyUserMedia
        case .camera:
            .camera
        case .photoLibrary:
            .photoLibrary
        case .demoSample:
            if let sampleID = photo.sourceSampleID {
                .demoSample(sampleID: sampleID)
            } else {
                throw GrowPhotoResolutionError.policyViolation
            }
        }
    }

    private func decodeIfPossible(
        _ data: Data,
        maxPixelSize: Int,
        sourceID: String
    ) async throws -> CGImage? {
        do {
            return try await decoder.image(
                data: data,
                maxPixelSize: maxPixelSize,
                sourceID: sourceID
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return nil
        }
    }

    private func decodeRequired(
        _ data: Data,
        maxPixelSize: Int,
        sourceID: String
    ) async throws -> CGImage {
        do {
            return try await decoder.image(
                data: data,
                maxPixelSize: maxPixelSize,
                sourceID: sourceID
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw GrowPhotoResolutionError.decodeFailed
        }
    }
}
