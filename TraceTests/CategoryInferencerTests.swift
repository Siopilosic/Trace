import XCTest
@testable import Trace

final class CategoryInferencerTests: XCTestCase {
    let inferencer = CategoryInferencer()

    func testKnownMerchants() {
        XCTAssertEqual(inferencer.category(for: "McDonald's"), .food)
        XCTAssertEqual(inferencer.category(for: "uber to work"), .transport)
        XCTAssertEqual(inferencer.category(for: "Netflix"), .entertainment)
        XCTAssertEqual(inferencer.category(for: "Pharmacy"), .health)
        XCTAssertEqual(inferencer.category(for: "Amazon order"), .shopping)
        XCTAssertEqual(inferencer.category(for: "electricity"), .bills)
    }

    func testLongerPhraseWins() {
        XCTAssertEqual(inferencer.category(for: "gym membership"), .bills)
        XCTAssertEqual(inferencer.category(for: "gym"), .health)
    }

    func testUnknownReturnsNil() {
        XCTAssertNil(inferencer.category(for: "Xyzzy Corp"))
    }

    func testCaseInsensitive() {
        XCTAssertEqual(inferencer.category(for: "COFFEE"), .food)
    }
}
