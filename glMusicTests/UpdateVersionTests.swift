import XCTest
@testable import glMusic

final class UpdateVersionTests: XCTestCase {

    func testSemanticVersionComparison() {
        // v1 > v2 -> true
        XCTAssertTrue(UpdateManager.isVersion("1.0.1", greaterThan: "1.0.0"))
        XCTAssertTrue(UpdateManager.isVersion("1.1.0", greaterThan: "1.0.9"))
        XCTAssertTrue(UpdateManager.isVersion("2.0.0", greaterThan: "1.9.9"))
        XCTAssertTrue(UpdateManager.isVersion("1.0.10", greaterThan: "1.0.2"))
        XCTAssertTrue(UpdateManager.isVersion("0.4.0", greaterThan: "0.3.9"))
        XCTAssertTrue(UpdateManager.isVersion("1.0.0.1", greaterThan: "1.0.0"))

        // v1 <= v2 -> false
        XCTAssertFalse(UpdateManager.isVersion("1.0.0", greaterThan: "1.0.0"))
        XCTAssertFalse(UpdateManager.isVersion("0.3.8", greaterThan: "0.3.9"))
        XCTAssertFalse(UpdateManager.isVersion("1.0.2", greaterThan: "1.0.10"))
        XCTAssertFalse(UpdateManager.isVersion("1.0.0", greaterThan: "1.0.0.1"))
    }
}
