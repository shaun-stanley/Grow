import XCTest
@testable import Grow

final class DeepLinkRoutingTests: XCTestCase {
    func testGrowCaptureURLRoutesToCapture() throws {
        let url = try XCTUnwrap(URL(string: "grow://capture"))
        XCTAssertEqual(DeepLinkPolicy.destination(for: url), .capture)
    }

    func testGrowTodayURLRoutesToToday() throws {
        let url = try XCTUnwrap(URL(string: "grow://today"))
        XCTAssertEqual(DeepLinkPolicy.destination(for: url), .today)
    }

    func testUnknownOrForeignURLIsIgnored() throws {
        XCTAssertNil(DeepLinkPolicy.destination(for: try XCTUnwrap(URL(string: "grow://care"))))
        XCTAssertNil(DeepLinkPolicy.destination(for: try XCTUnwrap(URL(string: "https://capture"))))
    }
}
