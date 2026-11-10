//
//  LyricsService.swift
//  glMusic
//
//  Created by go love on 11/10/26.
//

import Foundation

/// 独立歌词解析、异步拉取与双语翻译匹配服务
final class LyricsService: Sendable {
    static let shared = LyricsService()

    private init() {}

    /// 加载指定歌曲的歌词（优先读取离线/伴生歌词，若无则拉取远端 YRC/LRC 并解析双语）
    func fetchLyrics(for songId: Int) async -> [LyricLine] {
        // 1. 优先检查本地是否下载了离线歌词 / 本地伴生歌词
        if let localLrc = await DownloadManager.shared.localLyrics(for: songId) {
            let localTrans = await DownloadManager.shared.localTranslation(for: songId)
            return parseLyrics(yrc: nil, lrc: localLrc, translation: localTrans)
        }

        // 2. 若为本地导入歌曲 (songId < 0) 且无本地伴生歌词，直接展示暂无本地歌词，不请求网络
        if songId < 0 {
            return [LyricLine(time: 0, text: "暂无本地歌词".localized)]
        }

        // 3. 网络拉取
        do {
            let resp = try await NetworkManager.shared.lyrics(id: songId)
            return parseLyrics(
                yrc: resp.yrc?.lyric,
                lrc: resp.lrc?.lyric,
                translation: resp.tlyric?.lyric
            )
        } catch {
            return [LyricLine(time: 0, text: "暂无歌词".localized)]
        }
    }

    /// 解析歌词（优先解析逐字 YRC，回退到 LRC，并关联双语翻译）
    func parseLyrics(yrc: String?, lrc: String?, translation: String?) -> [LyricLine] {
        if let yrc = yrc, !yrc.isEmpty {
            let yrcLines = parseYRC(yrc: yrc, translation: translation)
            if !yrcLines.isEmpty {
                return yrcLines
            }
        }
        return parseLRC(lrc: lrc, translation: translation)
    }

    /// 毫秒级逐字歌词 (YRC) 解析器
    func parseYRC(yrc: String, translation: String?) -> [LyricLine] {
        var lines: [LyricLine] = []
        let linePattern = /\[(\d+),(\d+)\](.*)/
        let wordPattern = /\((\d+),(\d+)(?:,\d+)?\)([^\(\)]*)/

        for rawLine in yrc.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard let lineMatch = trimmed.firstMatch(of: linePattern) else { continue }

            let lineStartMs = Double(lineMatch.1) ?? 0
            let lineDurMs = Double(lineMatch.2) ?? 0
            let lineBody = String(lineMatch.3)

            let lineStartTime = lineStartMs / 1000.0
            let lineDuration = lineDurMs / 1000.0

            var words: [LyricWord] = []
            var fullText = ""

            let wordMatches = lineBody.matches(of: wordPattern)
            for wm in wordMatches {
                let wStartMs = Double(wm.1) ?? 0
                let wDurMs = Double(wm.2) ?? 0
                let wText = String(wm.3)

                let wStartTime = wStartMs / 1000.0
                let wDuration = wDurMs / 1000.0

                if !wText.isEmpty {
                    words.append(LyricWord(time: wStartTime, duration: wDuration, text: wText))
                    fullText += wText
                }
            }

            let cleanText = fullText.trimmingCharacters(in: .whitespaces)
            if !cleanText.isEmpty {
                lines.append(LyricLine(
                    time: lineStartTime,
                    text: cleanText,
                    duration: lineDuration,
                    words: words
                ))
            }
        }

        guard !lines.isEmpty else { return [] }
        attachTranslation(to: &lines, translation: translation)
        return lines.sorted { $0.time < $1.time }
    }

    /// 标准行级歌词 (LRC) 解析器
    func parseLRC(lrc: String?, translation: String?) -> [LyricLine] {
        guard let lrc = lrc, !lrc.isEmpty else { return [] }

        var lines: [LyricLine] = []
        let pattern = /\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\](.*)/

        for rawLine in lrc.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if let match = trimmed.firstMatch(of: pattern) {
                let min = Double(match.1) ?? 0
                let sec = Double(match.2) ?? 0
                let msStr = match.3.map(String.init) ?? "0"
                let ms = (Double(msStr) ?? 0) / (msStr.count == 3 ? 1000.0 : 100.0)
                let time = min * 60 + sec + ms
                let text = String(match.4).trimmingCharacters(in: .whitespaces)

                if !text.isEmpty {
                    lines.append(LyricLine(time: time, text: text))
                }
            }
        }

        attachTranslation(to: &lines, translation: translation)

        var sortedLines = lines.sorted { $0.time < $1.time }

        // 计算每行歌词的持续时间：基于字数 × 320ms/字，并用下一行时间戳防溢出
        for i in 0..<sortedLines.count {
            if i < sortedLines.count - 1 {
                let diff = sortedLines[i + 1].time - sortedLines[i].time
                let textLength = Double(sortedLines[i].text.count)
                let estimatedSingTime = max(1.2, min(diff - 0.4, textLength * 0.32))
                sortedLines[i].duration = max(1.0, estimatedSingTime)
            } else {
                sortedLines[i].duration = 5.0
            }
        }

        return sortedLines
    }

    /// 双语翻译对齐算法
    func attachTranslation(to lines: inout [LyricLine], translation: String?) {
        guard let trans = translation, !trans.isEmpty else { return }
        let pattern = /\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\](.*)/
        var transDict: [Int: String] = [:]

        for rawLine in trans.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if let match = trimmed.firstMatch(of: pattern) {
                let min = Double(match.1) ?? 0
                let sec = Double(match.2) ?? 0
                let msStr = match.3.map(String.init) ?? "0"
                let ms = (Double(msStr) ?? 0) / (msStr.count == 3 ? 1000.0 : 100.0)
                let timeMs = Int((min * 60 + sec + ms) * 10)
                let text = String(match.4).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    transDict[timeMs] = text
                }
            }
        }

        for i in 0..<lines.count {
            let key = Int(lines[i].time * 10)
            for offset in [-3, -2, -1, 0, 1, 2, 3] {
                if let t = transDict[key + offset] {
                    lines[i].translation = t
                    break
                }
            }
        }
    }

    /// 根据播放时间定位当前歌词行索引（含 O(1) 局部跳跃与二分/线性保底查找）
    func findLyricIndex(at time: TimeInterval, in lyrics: [LyricLine], currentIndex: Int) -> Int {
        guard !lyrics.isEmpty else { return 0 }
        let count = lyrics.count
        let curr = currentIndex

        // 1. 快速检查是否依然处于当前行 (高频命中率 > 90%)
        if curr >= 0 && curr < count && lyrics[curr].time <= time && (curr + 1 >= count || lyrics[curr + 1].time > time) {
            return curr
        }

        // 2. 快速检查下一行 (行切换常见命中)
        if curr + 1 < count && lyrics[curr + 1].time <= time && (curr + 2 >= count || lyrics[curr + 2].time > time) {
            return curr + 1
        }

        // 3. 用户进度拖动或切歌时的快速查找
        if let idx = lyrics.lastIndex(where: { $0.time <= time }) {
            return idx
        }

        return 0
    }
}
