import CoreGraphics
import Foundation

enum ReelStudioStatus: Equatable {
    case noFrames
    case ready(progressPercent: Int)
    case rendering
    case rendered(frameCount: Int, durationText: String)
    case failed(String)
}

enum ReelStudioPolicy {
    static let defaultTargetFrameCount = 30

    static func progress(
        frameCount: Int,
        targetFrameCount: Int = defaultTargetFrameCount
    ) -> Double {
        guard targetFrameCount > 0 else { return 0 }
        return min(1, max(0, Double(frameCount) / Double(targetFrameCount)))
    }

    static func progressPercent(
        frameCount: Int,
        targetFrameCount: Int = defaultTargetFrameCount
    ) -> Int {
        Int((progress(frameCount: frameCount, targetFrameCount: targetFrameCount) * 100).rounded())
    }

    static func progressText(
        frameCount: Int,
        targetFrameCount: Int = defaultTargetFrameCount
    ) -> String {
        if frameCount <= 0 {
            return "Frame 1 is waiting"
        }
        if frameCount >= targetFrameCount {
            return "First \(targetFrameCount)-frame reel ready"
        }
        return "\(progressPercent(frameCount: frameCount, targetFrameCount: targetFrameCount))% of the first \(targetFrameCount)-frame reel"
    }

    static func durationText(_ duration: Double) -> String {
        String(format: "%.1fs", duration)
    }

    static func status(
        frameCount: Int,
        isRendering: Bool,
        renderedFrameCount: Int?,
        renderedDurationSeconds: Double?,
        errorMessage: String?
    ) -> ReelStudioStatus {
        if isRendering {
            return .rendering
        }
        if let errorMessage {
            return .failed(errorMessage)
        }
        if let renderedFrameCount, let renderedDurationSeconds {
            return .rendered(
                frameCount: renderedFrameCount,
                durationText: durationText(renderedDurationSeconds)
            )
        }
        if frameCount <= 0 {
            return .noFrames
        }
        return .ready(progressPercent: progressPercent(frameCount: frameCount))
    }

    static func shareURL(
        localFileName: String,
        containerURL: URL,
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL? {
        guard !localFileName.isEmpty else { return nil }
        let url = containerURL.appendingPathComponent(localFileName)
        guard fileExists(url) else { return nil }
        return url
    }
}

enum ReelStudioVisualContract {
    static let previewMaxWidth: CGFloat = 258
    static let previewAspectRatio: CGFloat = 9.0 / 16.0
    static let primaryActionHeight: CGFloat = 52
    static let shareButtonSize: CGFloat = 52
    static let exportThumbnailWidth: CGFloat = 40
    static let exportThumbnailHeight: CGFloat = 54
    static let exportRowVerticalPadding: CGFloat = 10
    static let exportRowHorizontalPadding: CGFloat = 12
    static let bottomScrollPadding: CGFloat = 96

    static let antiSlopChecklist = [
        "Apple native system typography only",
        "Preview, action, and status visible in first viewport",
        "Even padding inside Reels surfaces",
        "No nested-card effect",
        "Share icon aligned to primary action height",
        "Export rows use fixed 9:16 thumbnails",
        "No generic AI-generated mobile card stack"
    ]
}
