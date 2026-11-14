//
//  HomeHeroTilesView.swift
//  glMusic
//
//  Created by go love on 11/14/26.
//

import SwiftUI

struct HomeHeroTilesView: View {
    @Binding var selection: String?
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager

    @State private var isHoveringFM = false
    @State private var isHoveringDaily = false
    @State private var isLoadingDaily = false
    @State private var showTrashToast = false
    @State private var trashToastText = ""

    private var todayDayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: Date())
    }

    private var todayWeekday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }

    var body: some View {
        HStack(spacing: 16) {
            personalFMTile
            dailyRecommendTile
        }
        .overlay(alignment: .top) {
            if showTrashToast {
                Text(trashToastText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.8), in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, -8)
            }
        }
    }

    // MARK: - 私人 FM 专属磁贴

    private var personalFMTile: some View {
        ZStack {
            // 背景渐变与磨砂玻璃
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.22),
                            Color.blue.opacity(0.12),
                            Color.black.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(isHoveringFM ? 0.35 : 0.15),
                                    .white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            VStack(alignment: .leading, spacing: 10) {
                // 顶部状态标识
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(themeManager.accentColor)

                        Text("私人 FM".localized)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(themeManager.accentColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(themeManager.accentColor.opacity(0.15), in: Capsule())

                    Spacer()

                    if player.isPersonalFM && player.isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(themeManager.accentColor)
                    }
                }

                // 中间信息 (点击直达私人 FM 独立沉浸界面)
                HStack(spacing: 12) {
                    if player.isPersonalFM, let current = player.currentSong {
                        // 正在播放的 FM 封面与信息
                        SongCoverThumbnailView(song: current, size: 50)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(current.name)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                            Text(current.displayArtist)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        // 默认 FM 封面标识
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 50, height: 50)
                                .shadow(color: .purple.opacity(0.35), radius: 6, y: 3)

                            Image(systemName: "radio.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("私人音乐电台".localized)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                            Text("基于品味智能漫游 · 永不停止".localized)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selection = "personalFm"
                }

                Spacer(minLength: 0)

                // 快捷手势与操作工具条
                HStack(spacing: 16) {
                    // 垃圾桶（不喜欢 / 不再推荐）
                    Button {
                        handleTrash()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("不喜欢并从私人 FM 移除（不再推荐）".localized)

                    // 红心喜欢
                    if let song = player.currentSong {
                        Button {
                            player.toggleLike(for: song)
                        } label: {
                            Image(systemName: player.isLiked(song.id) ? "heart.fill" : "heart")
                                .font(.system(size: 14))
                                .foregroundStyle(player.isLiked(song.id) ? themeManager.accentColor : .secondary)
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help((player.isLiked(song.id) ? "取消喜欢" : "喜欢这首歌").localized)
                    }

                    Spacer()

                    // 下一首
                    Button {
                        if player.isPersonalFM {
                            player.next()
                        } else {
                            player.startPersonalFM()
                        }
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("下一首".localized)

                    // 播放 / 暂停 主按键
                    Button {
                        if player.isPersonalFM {
                            player.togglePlay()
                        } else {
                            player.startPersonalFM()
                        }
                    } label: {
                        Image(systemName: (player.isPersonalFM && player.isPlaying) ? "pause.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(themeManager.accentColor, in: Circle())
                            .shadow(color: themeManager.accentColor.opacity(0.4), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                    .help((player.isPersonalFM && player.isPlaying ? "暂停" : "播放私人 FM").localized)
                }
            }
            .padding(14)
        }
        .frame(height: 142)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHoveringFM = h
            }
        }
    }

    // MARK: - 每日推荐 30 首 专属磁贴

    private var dailyRecommendTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.18),
                            Color.pink.opacity(0.12),
                            Color.black.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(isHoveringDaily ? 0.35 : 0.15),
                                    .white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            VStack(alignment: .leading, spacing: 10) {
                // 顶部状态标识
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.orange)

                        Text("每日 6:00 更新".localized)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15), in: Capsule())

                    Spacer()

                    Text("专属定制 30 首".localized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // 中间信息：经典日历样式
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 50, height: 50)
                            .shadow(color: .orange.opacity(0.35), radius: 6, y: 3)

                        VStack(spacing: 0) {
                            Text(todayWeekday)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
                                .textCase(.uppercase)

                            Text(todayDayNumber)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("每日推荐 30 首".localized)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text("符合你音乐口味的每日专属歌单".localized)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                // 快捷操作工具条
                HStack(spacing: 10) {
                    // 查看完整每日推荐
                    Button {
                        selection = "daily"
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 11))
                            Text("查看全部".localized)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("查看每日推荐 30 首完整列表".localized)

                    Spacer()

                    // 一键播放全部 30 首
                    Button {
                        playDailyAll()
                    } label: {
                        HStack(spacing: 5) {
                            if isLoadingDaily {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            Text("播放全部".localized)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                        .shadow(color: .orange.opacity(0.35), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingDaily)
                    .help("一键播放今日专属推荐 30 首".localized)
                }
            }
            .padding(14)
        }
        .frame(height: 142)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHoveringDaily = h
            }
        }
    }

    // MARK: - Actions

    private func handleTrash() {
        if let current = player.currentSong {
            trashToastText = String(format: "已移至垃圾桶，将减少此类推荐".localized, current.name)
        } else {
            trashToastText = "已移至垃圾桶，将减少此类推荐".localized
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showTrashToast = true
        }
        player.trashCurrentFMSong()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.25)) {
                showTrashToast = false
            }
        }
    }

    private func playDailyAll() {
        isLoadingDaily = true
        Task {
            do {
                let songs = try await NetworkManager.shared.dailyRecommendSongs()
                if !songs.isEmpty {
                    player.playAll(songs)
                }
            } catch {
                print("一键播放每日推荐失败: \(error)")
            }
            isLoadingDaily = false
        }
    }
}
