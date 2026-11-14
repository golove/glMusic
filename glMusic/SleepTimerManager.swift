//
//  SleepTimerManager.swift
//  glMusic
//
//  Created by go love on 11/14/26.
//

import SwiftUI
import Foundation

enum SleepTimerOption: Equatable, Hashable, Identifiable {
    case off
    case minutes(Int)
    case endOfSong

    var id: String {
        switch self {
        case .off: return "off"
        case .minutes(let m): return "min_\(m)"
        case .endOfSong: return "end_of_song"
        }
    }

    var title: String {
        switch self {
        case .off:
            return "关闭".localized
        case .minutes(let m):
            return String(format: "%d 分钟".localized, m)
        case .endOfSong:
            return "播完当前歌曲".localized
        }
    }
}

/// 睡眠定时器管理器：支持 15/30/45/60 分钟与播完本曲自动停止，
/// 附带 10 秒自然柔和微淡出 (Night Smooth Fadeout)，0 CPU 极简耗能。
@MainActor
@Observable
final class SleepTimerManager {
    static let shared = SleepTimerManager()

    private(set) var activeOption: SleepTimerOption = .off
    private(set) var remainingSeconds: Int = 0

    var isActive: Bool {
        activeOption != .off
    }

    /// 剩余时间格式化（例如 "24:18" 或 "播完即停"）
    var remainingFormatted: String {
        switch activeOption {
        case .off:
            return ""
        case .endOfSong:
            return "播完即停".localized
        case .minutes:
            let m = remainingSeconds / 60
            let s = remainingSeconds % 60
            return String(format: "%02d:%02d", m, s)
        }
    }

    /// 短标签用于图标旁显示（如 "24m" 或 "1曲"）
    var shortBadgeText: String {
        switch activeOption {
        case .off:
            return ""
        case .endOfSong:
            return "1曲".localized
        case .minutes:
            let m = max(1, Int(ceil(Double(remainingSeconds) / 60.0)))
            return "\(m)m"
        }
    }

    private var timer: Timer?
    private var fadeTimer: Timer?
    private var originalVolume: Double?
    private weak var player: PlayerManager?

    private init() {}

    /// 开启定时器
    func start(option: SleepTimerOption, player: PlayerManager) {
        cancel()
        self.player = player
        self.activeOption = option

        switch option {
        case .off:
            break
        case .endOfSong:
            self.remainingSeconds = 0
        case .minutes(let mins):
            self.remainingSeconds = mins * 60
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.tick()
                }
            }
        }
    }

    /// 取消定时器
    func cancel() {
        timer?.invalidate()
        timer = nil
        fadeTimer?.invalidate()
        fadeTimer = nil

        if let orig = originalVolume, let p = player {
            p.volume = orig
        }
        originalVolume = nil
        activeOption = .off
        remainingSeconds = 0
    }

    /// 歌曲播放结束时调用（用于「播完当前歌曲」选项）
    func handleSongEnded() {
        guard activeOption == .endOfSong, let p = player else { return }
        p.pause()
        cancel()
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            finishTimer()
            return
        }

        remainingSeconds -= 1

        // 剩余最后 10 秒时启动平滑淡出，避免断崖式切断音乐惊醒睡眠中的用户
        if remainingSeconds == 10 {
            startSmoothFadeOut()
        }

        if remainingSeconds <= 0 {
            finishTimer()
        }
    }

    private func startSmoothFadeOut() {
        guard let p = player, originalVolume == nil else { return }
        let currentVol = p.volume
        self.originalVolume = currentVol

        var step = 0
        let totalSteps = 20 // 每 0.5s 一步，共 10s
        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] t in
            Task { @MainActor [weak self] in
                guard let self = self, let p = self.player else {
                    t.invalidate()
                    return
                }
                step += 1
                let progress = Double(step) / Double(totalSteps)
                let newVol = max(0.0, currentVol * (1.0 - progress))
                p.volume = newVol

                if step >= totalSteps {
                    t.invalidate()
                    self.fadeTimer = nil
                }
            }
        }
    }

    private func finishTimer() {
        timer?.invalidate()
        timer = nil
        fadeTimer?.invalidate()
        fadeTimer = nil

        if let p = player {
            p.pause()
            if let orig = originalVolume {
                p.volume = orig
            }
        }

        originalVolume = nil
        activeOption = .off
        remainingSeconds = 0
    }
}
