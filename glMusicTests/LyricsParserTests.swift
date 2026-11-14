import XCTest
@testable import glMusic

final class LyricsParserTests: XCTestCase {

    func testStandardLrcParsing() {
        let lrcContent = """
        [00:01.00]第一行歌词
        [00:05.50]第二行歌词
        [00:10.123]第三行歌词带毫秒
        """

        let lines = LyricsService.shared.parseLRC(lrc: lrcContent, translation: nil)
        XCTAssertEqual(lines.count, 3)

        XCTAssertEqual(lines[0].time, 1.0, accuracy: 0.01)
        XCTAssertEqual(lines[0].text, "第一行歌词")

        XCTAssertEqual(lines[1].time, 5.5, accuracy: 0.01)
        XCTAssertEqual(lines[1].text, "第二行歌词")

        XCTAssertEqual(lines[2].time, 10.123, accuracy: 0.01)
        XCTAssertEqual(lines[2].text, "第三行歌词带毫秒")
    }

    func testLrcTranslationAttachment() {
        let lrcContent = """
        [00:02.00]Hello world
        [00:06.00]Good morning
        """

        let transContent = """
        [00:02.00]你好世界
        [00:06.02]早上好
        """

        let lines = LyricsService.shared.parseLRC(lrc: lrcContent, translation: transContent)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].translation, "你好世界")
        XCTAssertEqual(lines[1].translation, "早上好")
    }

    func testYrcWordLevelParsing() {
        let yrcContent = """
        [1000,3000](1000,500)你(1500,500)好(2000,2000)世界
        """

        let lines = LyricsService.shared.parseYRC(yrc: yrcContent, translation: nil)
        XCTAssertEqual(lines.count, 1)

        let line = lines[0]
        XCTAssertEqual(line.time, 1.0, accuracy: 0.01)
        XCTAssertEqual(line.duration, 3.0, accuracy: 0.01)
        XCTAssertEqual(line.text, "你好世界")
        XCTAssertEqual(line.words.count, 3)

        XCTAssertEqual(line.words[0].text, "你")
        XCTAssertEqual(line.words[0].time, 1.0, accuracy: 0.01)
        XCTAssertEqual(line.words[0].duration, 0.5, accuracy: 0.01)

        XCTAssertEqual(line.words[1].text, "好")
        XCTAssertEqual(line.words[1].time, 1.5, accuracy: 0.01)
        XCTAssertEqual(line.words[1].duration, 0.5, accuracy: 0.01)
    }

    func testFindLyricIndex() {
        let lines = [
            LyricLine(time: 2.0, text: "Line 1"),
            LyricLine(time: 5.0, text: "Line 2"),
            LyricLine(time: 9.0, text: "Line 3")
        ]

        // 歌曲刚开始，未到第一行
        XCTAssertEqual(LyricsService.shared.findLyricIndex(at: 0.5, in: lines, currentIndex: 0), 0)

        // 第一行时间内
        XCTAssertEqual(LyricsService.shared.findLyricIndex(at: 2.5, in: lines, currentIndex: 0), 0)

        // 第二行时间内
        XCTAssertEqual(LyricsService.shared.findLyricIndex(at: 5.5, in: lines, currentIndex: 0), 1)

        // 超过最后一行
        XCTAssertEqual(LyricsService.shared.findLyricIndex(at: 12.0, in: lines, currentIndex: 1), 2)
    }
}
