import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import Observation
import QuartzCore
import SwiftData
import UIKit

struct ReelRenderResult: Equatable {
    let reelID: UUID
    let outputURL: URL
    let localFileName: String
    let frameCount: Int
    let durationSeconds: Double
    let renderedAt: Date
}

@MainActor
@Observable
final class ReelRenderingService {
    private let context: ModelContext
    private let canvasSize = CGSize(width: 1080, height: 1920)
    private let frameHoldDuration = CMTime(value: 18, timescale: 30)

    var isRendering = false
    var lastResult: ReelRenderResult?
    var lastErrorMessage: String?

    init(context: ModelContext) {
        self.context = context
    }

    func renderPreview(for grow: Grow, species: PlantSpecies?) async {
        guard !isRendering else { return }
        isRendering = true
        lastErrorMessage = nil
        defer { isRendering = false }

        do {
            lastResult = try await renderPreviewFile(for: grow, species: species)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func renderPreviewFile(for grow: Grow, species: PlantSpecies?) async throws -> ReelRenderResult {
        let photos = (grow.photos ?? []).sorted { $0.capturedAt < $1.capturedAt }
        guard !photos.isEmpty else { throw ReelRenderingError.noFrames }

        let frames = photos.enumerated().map { index, photo in
            ReelSourceFrame(
                photo: photo,
                image: image(for: photo),
                progress: min(1, Double(index + 1) / 30)
            )
        }

        let reelID = UUID()
        let localFileName = "Reels/\(grow.id.uuidString)/\(reelID.uuidString).mov"
        let outputURL = AppGroup.containerURL.appendingPathComponent(localFileName)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let firstComposited = try compositedFrame(
            source: frames[0],
            sourceIndex: 0,
            totalFrames: frames.count,
            species: species,
            grow: grow
        )

        try await writeMovie(
            frames: frames,
            firstCompositedFrame: firstComposited,
            outputURL: outputURL,
            species: species,
            grow: grow
        )

        let renderedAt = Date()
        let reel = Reel(createdAt: renderedAt)
        reel.id = reelID
        reel.localFileName = localFileName
        reel.posterFrameData = firstComposited.jpegData(compressionQuality: 0.78)
        reel.sourcePhotoStart = photos.first?.capturedAt ?? renderedAt
        reel.sourcePhotoEnd = photos.last?.capturedAt ?? renderedAt
        reel.photoCount = photos.count
        reel.durationSeconds = CMTimeGetSeconds(frameHoldDuration) * Double(frames.count)
        reel.styleRaw = "fieldJournalHarness"
        reel.grow = grow
        context.insert(reel)
        try context.save()

        return ReelRenderResult(
            reelID: reelID,
            outputURL: outputURL,
            localFileName: localFileName,
            frameCount: photos.count,
            durationSeconds: reel.durationSeconds,
            renderedAt: renderedAt
        )
    }

    private func writeMovie(
        frames: [ReelSourceFrame],
        firstCompositedFrame: UIImage,
        outputURL: URL,
        species: PlantSpecies?,
        grow: Grow
    ) async throws {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 7_200_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
        )
        input.expectsMediaDataInRealTime = false

        let pixelBufferAttributes = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA),
            size: CVImageSize(width: width, height: height),
            compatibility: [.cgBitmapContext, .cgImage]
        )
        let receiver = writer.inputPixelBufferReceiver(
            for: input,
            pixelBufferAttributes: pixelBufferAttributes
        )

        guard writer.startWriting() else {
            throw ReelRenderingError.writerFailed(writer.error?.localizedDescription)
        }
        writer.startSession(atSourceTime: .zero)

        var lastImage = firstCompositedFrame
        for index in frames.indices {
            let image: UIImage
            if index == 0 {
                image = firstCompositedFrame
            } else {
                image = try compositedFrame(
                    source: frames[index],
                    sourceIndex: index,
                    totalFrames: frames.count,
                    species: species,
                    grow: grow
                )
            }
            lastImage = image
            let presentationTime = CMTimeMultiply(frameHoldDuration, multiplier: Int32(index))
            let pixelBuffer = try readOnlyPixelBuffer(from: image, attributes: pixelBufferAttributes)
            try await receiver.append(pixelBuffer, with: presentationTime)
        }

        let finalTime = CMTimeMultiply(frameHoldDuration, multiplier: Int32(frames.count))
        let finalPixelBuffer = try readOnlyPixelBuffer(from: lastImage, attributes: pixelBufferAttributes)
        try await receiver.append(finalPixelBuffer, with: finalTime)
        receiver.finish()
        try await finishWriting(writer)
    }

    private func finishWriting(_ writer: AVAssetWriter) async throws {
        let writerBox = AssetWriterBox(writer)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writerBox.writer.finishWriting {
                switch writerBox.writer.status {
                case .completed:
                    continuation.resume()
                default:
                    continuation.resume(throwing: ReelRenderingError.writerFailed(writerBox.writer.error?.localizedDescription))
                }
            }
        }
    }

    private func readOnlyPixelBuffer(
        from image: UIImage,
        attributes: CVPixelBufferCreationAttributes
    ) throws -> CVReadOnlyPixelBuffer {
        guard let cgImage = image.cgImage else { throw ReelRenderingError.cgImageUnavailable }
        var mutableBuffer = try CVMutablePixelBuffer(attributes)
        try mutableBuffer.accessUnsafeMutableRawPlaneBytes { planes in
            guard let plane = planes.first else { throw ReelRenderingError.pixelPlaneUnavailable }
            guard let baseAddress = plane.bytes.baseAddress else { throw ReelRenderingError.pixelPlaneUnavailable }

            let width = plane.properties.size.width
            let height = plane.properties.size.height
            guard
                let bitmapContext = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: plane.properties.bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
                )
            else {
                throw ReelRenderingError.bitmapContextUnavailable
            }

            bitmapContext.clear(CGRect(x: 0, y: 0, width: width, height: height))
            bitmapContext.interpolationQuality = .high
            bitmapContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return CVReadOnlyPixelBuffer(mutableBuffer)
    }

    private func compositedFrame(
        source: ReelSourceFrame,
        sourceIndex: Int,
        totalFrames: Int,
        species: PlantSpecies?,
        grow: Grow
    ) throws -> UIImage {
        guard let sourceImage = source.image.cgImage else { throw ReelRenderingError.cgImageUnavailable }

        let scale: CGFloat = 1
        let root = CALayer()
        root.frame = CGRect(origin: .zero, size: canvasSize)
        root.backgroundColor = UIColor(hex: 0xF3ECDC).cgColor
        root.contentsScale = scale

        let photoLayer = CALayer()
        photoLayer.frame = root.bounds
        photoLayer.contents = sourceImage
        photoLayer.contentsGravity = .resizeAspectFill
        photoLayer.masksToBounds = true
        photoLayer.contentsScale = scale
        root.addSublayer(photoLayer)

        let warmWash = CALayer()
        warmWash.frame = root.bounds
        warmWash.backgroundColor = UIColor(hex: 0xF3ECDC).withAlphaComponent(0.08).cgColor
        root.addSublayer(warmWash)

        let bottomGradient = CAGradientLayer()
        bottomGradient.frame = CGRect(x: 0, y: 1120, width: canvasSize.width, height: 800)
        bottomGradient.colors = [
            UIColor.clear.cgColor,
            UIColor(hex: 0x12150E).withAlphaComponent(0.72).cgColor
        ]
        bottomGradient.locations = [0, 1]
        root.addSublayer(bottomGradient)

        let topGradient = CAGradientLayer()
        topGradient.frame = CGRect(x: 0, y: 0, width: canvasSize.width, height: 420)
        topGradient.colors = [
            UIColor(hex: 0xF3ECDC).withAlphaComponent(0.72).cgColor,
            UIColor.clear.cgColor
        ]
        topGradient.locations = [0, 1]
        root.addSublayer(topGradient)

        addTextLayer(
            "GROW REEL",
            frame: CGRect(x: 74, y: 90, width: 660, height: 54),
            font: .systemFont(ofSize: 32, weight: .semibold),
            color: UIColor(hex: 0x2C7C3C),
            to: root,
            scale: scale
        )
        addTextLayer(
            displayName(for: grow, species: species),
            frame: CGRect(x: 74, y: 145, width: 880, height: 92),
            font: .systemFont(ofSize: 68, weight: .semibold),
            color: UIColor(hex: 0x223024),
            to: root,
            scale: scale
        )
        addTextLayer(
            "Day \(source.photo.dayIndex)",
            frame: CGRect(x: 74, y: 1492, width: 560, height: 120),
            font: .systemFont(ofSize: 88, weight: .medium),
            color: .white,
            to: root,
            scale: scale
        )
        addTextLayer(
            "\(sourceIndex + 1) of \(totalFrames) frames",
            frame: CGRect(x: 78, y: 1618, width: 520, height: 54),
            font: .systemFont(ofSize: 35, weight: .medium),
            color: UIColor.white.withAlphaComponent(0.82),
            to: root,
            scale: scale
        )
        addTextLayer(
            "SVIFT STUDIOS",
            frame: CGRect(x: 718, y: 1662, width: 286, height: 44),
            font: .systemFont(ofSize: 27, weight: .semibold),
            color: UIColor.white.withAlphaComponent(0.72),
            alignment: .right,
            to: root,
            scale: scale
        )

        let track = CALayer()
        track.frame = CGRect(x: 74, y: 1748, width: 932, height: 20)
        track.cornerRadius = 10
        track.backgroundColor = UIColor.white.withAlphaComponent(0.28).cgColor
        root.addSublayer(track)

        let fill = CALayer()
        fill.frame = CGRect(x: 74, y: 1748, width: 932 * min(1, max(0.04, source.progress)), height: 20)
        fill.cornerRadius = 10
        fill.backgroundColor = UIColor(hex: 0xF0A04A).cgColor
        root.addSublayer(fill)

        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = 1
        rendererFormat.opaque = true
        return UIGraphicsImageRenderer(size: canvasSize, format: rendererFormat).image { renderContext in
            root.render(in: renderContext.cgContext)
        }
    }

    private func addTextLayer(
        _ text: String,
        frame: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: CATextLayerAlignmentMode = .left,
        to parent: CALayer,
        scale: CGFloat
    ) {
        let layer = CATextLayer()
        layer.frame = frame
        layer.string = text
        layer.font = font
        layer.fontSize = font.pointSize
        layer.foregroundColor = color.cgColor
        layer.alignmentMode = alignment
        layer.truncationMode = .end
        layer.contentsScale = scale
        parent.addSublayer(layer)
    }

    private func image(for photo: GrowPhoto) -> UIImage {
        if !photo.localFileName.isEmpty {
            let url = AppGroup.containerURL.appendingPathComponent(photo.localFileName)
            if let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }

        if let thumbnailData = photo.thumbnailData, let image = UIImage(data: thumbnailData) {
            return image
        }

        return fallbackImage()
    }

    private func fallbackImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
            let cgContext = context.cgContext
            UIColor(hex: 0xF6EEDC).setFill()
            cgContext.fill(CGRect(origin: .zero, size: canvasSize))

            UIColor(hex: 0xFFCB73).withAlphaComponent(0.22).setFill()
            cgContext.fillEllipse(in: CGRect(x: 162, y: 350, width: 756, height: 756))

            let jar = CGRect(x: 265, y: 660, width: 550, height: 760)
            let jarPath = UIBezierPath(roundedRect: jar, cornerRadius: 118)
            UIColor.white.withAlphaComponent(0.36).setFill()
            jarPath.fill()
            UIColor(hex: 0xCDE7BE).setStroke()
            jarPath.lineWidth = 5
            jarPath.stroke()

            let stem = UIBezierPath()
            stem.move(to: CGPoint(x: jar.midX, y: jar.maxY - 130))
            stem.addCurve(
                to: CGPoint(x: jar.midX + 8, y: jar.minY + 170),
                controlPoint1: CGPoint(x: jar.midX - 80, y: jar.maxY - 410),
                controlPoint2: CGPoint(x: jar.midX + 84, y: jar.minY + 330)
            )
            UIColor(hex: 0x3E9E4F).setStroke()
            stem.lineWidth = 16
            stem.lineCapStyle = .round
            stem.stroke()
        }
    }

    private func displayName(for grow: Grow, species: PlantSpecies?) -> String {
        grow.nickname.isEmpty ? (species?.commonName ?? "My plant") : grow.nickname
    }
}

private struct ReelSourceFrame {
    let photo: GrowPhoto
    let image: UIImage
    let progress: Double
}

private final class AssetWriterBox: @unchecked Sendable {
    let writer: AVAssetWriter

    init(_ writer: AVAssetWriter) {
        self.writer = writer
    }
}

enum ReelRenderingError: LocalizedError {
    case noFrames
    case cgImageUnavailable
    case pixelPlaneUnavailable
    case bitmapContextUnavailable
    case writerFailed(String?)

    var errorDescription: String? {
        switch self {
        case .noFrames:
            "Capture a plant photo before rendering a reel."
        case .cgImageUnavailable:
            "Grow could not prepare one of the reel frames."
        case .pixelPlaneUnavailable:
            "Grow could not allocate video frame memory."
        case .bitmapContextUnavailable:
            "Grow could not draw into the video frame."
        case .writerFailed(let message):
            message ?? "Grow could not finish the reel export."
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
