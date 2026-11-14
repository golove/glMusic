import XCTest
@testable import glMusic

final class SleepTimerTests: XCTestCase {

    override func setUp() async throws {
        await SleepTimerManager.shared.cancel()
    }

    override func tearDown() async throws {
        await SleepTimerManager.shared.cancel()
    }

    func testInitialState() async {
        let mgr = SleepTimerManager.shared
        XCTAssertFalse(mgr.isActive)
        XCTAssertEqual(mgr.activeOption, .off)
        XCTAssertEqual(mgr.remainingSeconds, 0)
        XCTAssertEqual(mgr.remainingFormatted, "")
        XCTAssertEqual(mgr.shortBadgeText, "")
    }

    func testMinutesTimerStartAndCancel() async {
        let mgr = SleepTimerManager.shared
        let player = PlayerManager()

        mgr.start(option: .minutes(15), player: player)

        XCTAssertTrue(mgr.isActive)
        XCTAssertEqual(mgr.activeOption, .minutes(15))
        XCTAssertEqual(mgr.remainingSeconds, 900)
        XCTAssertEqual(mgr.shortBadgeText, "15m")
        XCTAssertEqual(mgr.remainingFormatted, "15:00")

        mgr.cancel()

        XCTAssertFalse(mgr.isActive)
        XCTAssertEqual(mgr.activeOption, .off)
        XCTAssertEqual(mgr.remainingSeconds, 0)
    }

    func testEndOfSongOptionAndCompletion() async {
        let mgr = SleepTimerManager.shared
        let player = PlayerManager()

        mgr.start(option: .endOfSong, player: player)

        XCTAssertTrue(mgr.isActive)
        XCTAssertEqual(mgr.activeOption, .endOfSong)
        XCTAssertEqual(mgr.remainingFormatted, "播完即停")
        XCTAssertEqual(mgr.shortBadgeText, "1曲")

        mgr.handleSongEnded()

        XCTAssertFalse(mgr.isActive)
        XCTAssertEqual(mgr.activeOption, .off)
    }
}
