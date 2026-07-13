import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Grow

final class GrowImageDecoderTests: XCTestCase {
    func testDownsamplesAndNormalizesEXIFOrientation() async throws {
        let decoder = GrowImageDecoder()
        let data = try fixtureData(
            width: 120,
            height: 60,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            orientation: 6
        )

        let image = try await decoder.image(data: data, maxPixelSize: 80)

        XCTAssertLessThanOrEqual(max(image.width, image.height), 80)
        XCTAssertGreaterThan(image.height, image.width)
    }

    func testDisplayP3FixtureDecodesWithValidColorOutput() async throws {
        let decoder = GrowImageDecoder()
        let data = try fixtureData(
            width: 96,
            height: 72,
            colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!
        )

        let image = try await decoder.image(data: data, maxPixelSize: 96)

        XCTAssertEqual(image.colorSpace?.model, .rgb)
        XCTAssertGreaterThan(image.bytesPerRow, 0)
    }

    func testGrayscaleFixtureDecodesWithValidColorOutput() async throws {
        let decoder = GrowImageDecoder()
        let data = try grayscaleFixtureData(width: 80, height: 64)

        let image = try await decoder.image(data: data, maxPixelSize: 80)

        XCTAssertNotNil(image.colorSpace)
        XCTAssertTrue([CGColorSpaceModel.monochrome, .rgb].contains(image.colorSpace?.model))
        XCTAssertGreaterThan(image.bytesPerRow, 0)
    }

    func testCancelledResolverStopsBeforeDecode() async throws {
        let photo = GrowPhoto(capturedAt: .now, dayIndex: 1)
        photo.origin = .camera
        photo.localFileName = "Photos/cancelled.jpg"
        let resolver = GrowPhotoSourceResolver(
            decoder: GrowImageDecoder(),
            fullSizeData: { _ in
                try await Task.sleep(for: .seconds(60))
                return Data()
            },
            demoAssetByID: { _ in nil },
            demoAssetForDay: { _ in nil }
        )

        let task = Task {
            try await resolver.resolve(
                photo: photo,
                policy: .genuineMediaOnly,
                targetMaxPixel: 512
            )
        }
        await Task.yield()
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testRepeatedLargeDecodesStayWithinCacheCostLimit() async throws {
        let decoder = GrowImageDecoder()
        let data = try fixtureData(
            width: 1_024,
            height: 1_024,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        )

        for index in 0..<30 {
            _ = try await decoder.image(
                data: data,
                maxPixelSize: 1_024,
                sourceID: "memory-harness-\(index)"
            )
        }

        let estimatedCost = await decoder.estimatedCacheCost
        XCTAssertLessThanOrEqual(estimatedCost, GrowImageDecoder.cacheCostLimit)
    }

    private func fixtureData(
        width: Int,
        height: Int,
        colorSpace: CGColorSpace,
        orientation: Int = 1
    ) throws -> Data {
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(red: 0.2, green: 0.8, blue: 0.35, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())
        return try encodedJPEG(image: image, orientation: orientation)
    }

    private func grayscaleFixtureData(width: Int, height: Int) throws -> Data {
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )
        )
        context.setFillColor(gray: 0.55, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())
        return try encodedJPEG(image: image, orientation: 1)
    }

    private func encodedJPEG(image: CGImage, orientation: Int) throws -> Data {
        let data = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(
                data,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        )
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImagePropertyOrientation: orientation] as CFDictionary
        )
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
