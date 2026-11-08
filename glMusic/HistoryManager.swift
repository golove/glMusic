//
//  HistoryManager.swift
//  glMusic
//
//  Created by go love on 11/8/26.
//

import SwiftUI
import Foundation

/// 播放历史条目
struct PlayHistoryItem: Identifiable, Codable, Equatable, Hashable {
    var id: String { "\(song.id)_\(Int(playedAt.timeIntervalSince1970))" }
    let song: APISong
    var playedAt: Date
    var playCount: Int

    init(song: APISong, playedAt: Date = Date(), playCount: Int = 1) {
        self.song = song
        self.playedAt = playedAt
        self.playCount = playCount
    }

    /// 相对播放时间展示，例如“刚刚”、“15分钟前”、“今天 14:30”、“昨天 09:12”、“11-04 12:00”
    var relativeTimeText: String {
        let now = Date()
        let interval = now.timeIntervalSince(playedAt)

        if interval < 60 {
            return "刚刚".localized
        } else if interval < 3600 {
            let minutes = max(1, Int(interval / 60))
            return "%d分钟前".localized(with: minutes)
        }

        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeString = timeFormatter.string(from: playedAt)

        if calendar.isDateInToday(playedAt) {
            return "今天 %@".localized(with: timeString)
        } else if calendar.isDateInYesterday(playedAt) {
            return "昨天 %@".localized(with: timeString)
        } else if calendar.isDate(playedAt, equalTo: now, toGranularity: .year) {
            let monthDayFormatter = DateFormatter()
            monthDayFormatter.dateFormat = "MM-dd HH:mm"
            return monthDayFormatter.string(from: playedAt)
        } else {
            let fullFormatter = DateFormatter()
            fullFormatter.dateFormat = "yyyy-MM-dd"
            return fullFormatter.string(from: playedAt)
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(song.id)
    }

    static func == (lhs: PlayHistoryItem, rhs: PlayHistoryItem) -> Bool {
        lhs.song.id == rhs.song.id && lhs.playedAt == rhs.playedAt
    }
}

/// 全局播放历史管理器（支持响应式更新与磁盘持久化）
@MainActor
@Observable
final class HistoryManager {
    static let shared = HistoryManager()

    var historyItems: [PlayHistoryItem] = []

    var songs: [APISong] {
        historyItems.map(\.song)
    }

    private let fileURL: URL
    private let maxHistoryCount = 300 // 最多保留 300 条最近播放记录

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = docs.appendingPathComponent("play_history.json")
        loadHistory()
    }

    /// 记录歌曲播放（若已在历史中，则移到最前并更新时间和听歌次数）
    func record(song: APISong) {
        // 过滤 3 秒内同一首歌的重复触发
        if let first = historyItems.first, first.song.id == song.id,
           Date().timeIntervalSince(first.playedAt) < 3 {
            return
        }

        if let existingIndex = historyItems.firstIndex(where: { $0.song.id == song.id }) {
            let existing = historyItems[existingIndex]
            let updated = PlayHistoryItem(
                song: song,
                playedAt: Date(),
                playCount: existing.playCount + 1
            )
            historyItems.remove(at: existingIndex)
            historyItems.insert(updated, at: 0)
        } else {
            let newItem = PlayHistoryItem(
                song: song,
                playedAt: Date(),
                playCount: 1
            )
            historyItems.insert(newItem, at: 0)
        }

        if historyItems.count > maxHistoryCount {
            historyItems = Array(historyItems.prefix(maxHistoryCount))
        }

        saveHistory()
    }

    /// 移除单条历史记录
    func remove(item: PlayHistoryItem) {
        historyItems.removeAll { $0.id == item.id || $0.song.id == item.song.id }
        saveHistory()
    }

    /// 移除某首歌曲的历史
    func remove(songId: Int) {
        historyItems.removeAll { $0.song.id == songId }
        saveHistory()
    }

    /// 清空所有播放历史
    func clearAll() {
        historyItems.removeAll()
        saveHistory()
    }

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let items = try? JSONDecoder().decode([PlayHistoryItem].self, from: data) else {
            return
        }
        self.historyItems = items
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(historyItems)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("❌ 保存播放历史失败: \(error)")
        }
    }
}
