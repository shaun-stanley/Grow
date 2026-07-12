import Foundation
import ImageIO

struct NormalizedPoint: Codable, Equatable, Sendable {
    let x: Double
    let y: Double

    var isValid: Bool {
        (0...1).contains(x) && (0...1).contains(y)
    }
}

enum DemoGrowCropIntent: String, Codable, CaseIterable, Sendable {
    case reelPortrait
    case memorySquare
    case timelineStrip
    case posterThumbnail
}

enum DemoGrowStoryMoment: String, Codable, Sendable {
    case setup
    case ordinary
    case harvest
    case finale
}

struct DemoGrowPhotoFrame: Codable, Equatable, Sendable {
    let id: String
    let fileName: String
    let day: Int
    let sequence: Int
    let moment: DemoGrowStoryMoment
    let focalPoints: [DemoGrowCropIntent: NormalizedPoint]
    let accessibilityKey: String
}

struct DemoGrowPhotoManifest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let storyID: String
    let maximumOrdinaryDay: Int
    let frames: [DemoGrowPhotoFrame]
}

enum DemoGrowPhotoLibraryError: Error, Equatable {
    case malformedManifest
    case duplicateID(String)
    case duplicateSequence(Int)
    case invalidFrame(String)
    case assetUnavailable(sampleID: String)
    case invalidRequestedDay
    case noPriorMaster
    case missingStoryMoment(DemoGrowStoryMoment)
}

struct DemoGrowPhotoAsset: Sendable {
    let frame: DemoGrowPhotoFrame
    let data: Data
}

struct DemoGrowPhotoLibrary: Sendable {
    private let manifest: DemoGrowPhotoManifest
    private let assets: [String: Data]

    init(manifestData: Data, assetData: (String) -> Data?) throws {
        guard let decoded = try? JSONDecoder().decode(DemoGrowPhotoManifest.self, from: manifestData),
              decoded.schemaVersion == 1,
              !decoded.frames.isEmpty else {
            throw DemoGrowPhotoLibraryError.malformedManifest
        }

        var ids = Set<String>()
        var sequences = Set<Int>()
        var loaded: [String: Data] = [:]
        for frame in decoded.frames {
            guard ids.insert(frame.id).inserted else {
                throw DemoGrowPhotoLibraryError.duplicateID(frame.id)
            }
            guard sequences.insert(frame.sequence).inserted else {
                throw DemoGrowPhotoLibraryError.duplicateSequence(frame.sequence)
            }
            guard frame.day >= 0,
                  frame.sequence >= 0,
                  Set(frame.focalPoints.keys) == Set(DemoGrowCropIntent.allCases),
                  frame.focalPoints.values.allSatisfy(\.isValid) else {
                throw DemoGrowPhotoLibraryError.invalidFrame(frame.id)
            }
            guard let data = assetData(frame.fileName),
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
                throw DemoGrowPhotoLibraryError.assetUnavailable(sampleID: frame.id)
            }
            loaded[frame.id] = data
        }

        manifest = decoded
        assets = loaded
    }

    func frame(forDay day: Int) throws -> DemoGrowPhotoFrame {
        guard day >= 0 else {
            throw DemoGrowPhotoLibraryError.invalidRequestedDay
        }
        let clamped = min(day, manifest.maximumOrdinaryDay)
        guard let frame = manifest.frames
            .filter({ $0.moment == .ordinary && $0.day <= clamped })
            .max(by: {
                $0.day == $1.day ? $0.sequence < $1.sequence : $0.day < $1.day
            }) else {
            throw DemoGrowPhotoLibraryError.noPriorMaster
        }
        return frame
    }

    func asset(forDay day: Int) throws -> DemoGrowPhotoAsset {
        let frame = try frame(forDay: day)
        guard let data = assets[frame.id] else {
            throw DemoGrowPhotoLibraryError.assetUnavailable(sampleID: frame.id)
        }
        return DemoGrowPhotoAsset(frame: frame, data: data)
    }

    func reelFrames() throws -> [DemoGrowPhotoFrame] {
        manifest.frames.sorted { $0.sequence < $1.sequence }
    }
}
