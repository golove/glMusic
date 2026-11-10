//
//  MenuBarView.swift
//  glMusic
//
//  Created by go love on 11/10/26.
//

import SwiftUI
import NeteaseCloudMusicAPI

struct MenuBarView: View {
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        @Bindable var player = player

        VStack(spacing: 12) {
            // MARK: - Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(themeManager.accentColor)

                    Text("glMusic")
                        .font(.system(size: 12, weight: .bold))
                }

                Spacer()

                HStack(spacing: 8) {
                    if DesktopLyricsManager.shared.isShowing {
                        // 桌面歌词外观设置
                        Button {
                            DesktopLyricsManager.shared.toggleSettings()
                        } label: {
                            Image(systemName: "paintpalette.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(DesktopLyricsManager.shared.isShowingSettings ? themeManager.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help("桌面歌词外观设置".localized)

                        // 桌面歌词锁定/解锁切换
                        Button {
                            DesktopLyricsManager.shared.toggleLock()
                        } label: {
                            Image(systemName: DesktopLyricsManager.shared.isLocked ? "lock.fill" : "lock.open.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(DesktopLyricsManager.shared.isLocked ? .orange : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(DesktopLyricsManager.shared.isLocked ? "解锁桌面歌词 (⇧⌘L)".localized : "锁定桌面歌词 (⇧⌘L)".localized)
                    }

                    // 桌面歌词开关
                    Button {
                        DesktopLyricsManager.shared.toggle()
                    } label: {
                        Image(systemName: DesktopLyricsManager.shared.isShowing ? "text.bubble.fill" : "text.bubble")
                            .font(.system(size: 11))
                            .foregroundStyle(DesktopLyricsManager.shared.isShowing ? themeManager.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("桌面悬浮歌词 (⇧⌘D)".localized)

                    // 打开主界面
                    Button {
                        openMainWindow()
                    } label: {
                        Image(systemName: "macwindow")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("打开 glMusic 主界面".localized)

                    // 退出
                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Image(systemName: "power")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("退出应用".localized)
                }
            }
            .padding(.horizontal, 4)

            Divider()
                .opacity(0.4)

            // MARK: - Song Info
            if let song = player.currentSong {
                HStack(spacing: 10) {
                    // 封面
                    if let localCover = DownloadManager.shared.localCoverURL(for: song.id),
                       let nsImg = NSImage(contentsOf: localCover) {
                        Image(nsImage: nsImg)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else if let coverUrl = song.coverUrl, !coverUrl.isEmpty {
                        AsyncImage(url: URL(string: coverUrl)) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .aspectRatio(contentMode: .fill)
                            default:
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.primary.opacity(0.06))
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                    )
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.06))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            )
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(song.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .foregroundStyle(.primary)

                        Text(song.displayArtist)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // 喜欢按钮
                    Button {
                        player.toggleLike(for: song)
                    } label: {
                        Image(systemName: player.isLiked(song.id) ? "heart.fill" : "heart")
                            .font(.system(size: 13))
                            .foregroundStyle(player.isLiked(song.id) ? themeManager.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(player.isLiked(song.id) ? "取消喜欢".localized : "喜欢这首歌".localized)
                }
                .padding(.horizontal, 4)

                // 进度条与时间 (独立隔离渲染)
                MenuBarProgressSection(player: player)
            } else {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 16))
                                .foregroundStyle(.tertiary)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("未在播放".localized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)

                        Text("点击打开主界面探索音乐".localized)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 4)
            }

            // MARK: - Playback Controls
            HStack(spacing: 16) {
                Button { player.toggleShuffle() } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 11))
                        .foregroundStyle(player.isShuffled ? themeManager.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("随机播放".localized)

                Button { player.previous() } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help("上一首 (⌘←)".localized)

                Button { player.togglePlay() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(themeManager.accentColor)
                }
                .buttonStyle(.plain)
                .help("播放/暂停 (空格)".localized)

                Button { player.next() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help("下一首 (⌘→)".localized)

                Button { player.cycleRepeat() } label: {
                    Image(systemName: player.repeatMode.systemImage)
                        .font(.system(size: 11))
                        .foregroundStyle(player.repeatMode.isActive ? themeManager.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("循环模式".localized)
            }
            .padding(.vertical, 2)

            // MARK: - Volume Bar
            HStack(spacing: 8) {
                Image(systemName: player.volume > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                Slider(value: $player.volume, in: 0...1)
                    .controlSize(.mini)
                    .tint(themeManager.accentColor)
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .frame(width: 270)
    }

    private func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
            window.deminiaturize(nil)
        }
    }
}

// MARK: - Isolated MenuBar Progress Section

private struct MenuBarProgressSection: View {
    @Bindable var player: PlayerManager

    var body: some View {
        VStack(spacing: 3) {
            ProgressSlider(value: $player.progress, trackHeight: 3)

            HStack {
                Text(player.currentTimeText)
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(player.remainingTimeText)
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
}
