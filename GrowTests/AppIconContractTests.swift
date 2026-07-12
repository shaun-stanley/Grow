import Foundation
import ImageIO
import XCTest

final class AppIconContractTests: XCTestCase {
    func testProductionIconIsOpaqueSquare1024PNG() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let root = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let icon = root.appendingPathComponent("Grow/Assets.xcassets/AppIcon.appiconset/GrowAppIcon.png")
        let data = try Data(contentsOf: icon)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )
        XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, 1024)
        XCTAssertEqual(properties[kCGImagePropertyPixelHeight] as? Int, 1024)
        XCTAssertEqual(CGImageSourceGetType(source) as String?, "public.png")
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertTrue([.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo))
    }

    func testAssetCatalogReferencesProductionIcon() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let root = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let contents = try String(
            contentsOf: root.appendingPathComponent(
                "Grow/Assets.xcassets/AppIcon.appiconset/Contents.json"
            ),
            encoding: .utf8
        )
        XCTAssertTrue(contents.contains("GrowAppIcon.png"))
    }
}
