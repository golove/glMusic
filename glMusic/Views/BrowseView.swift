//
//  BrowseView.swift
//  glMusic
//
//  Created by go love on 11/2/26.
//

import SwiftUI

/// 榜单浏览视图
struct BrowseView: View {
    @Binding var selection: String?
    @Environment(PlayerManager.self) private var player
    @State private var charts: [APIPlaylist] = BrowseDataCache.shared.cachedData?.charts ?? []
    @State private var isLoading = BrowseDataCache.shared.cachedData == nil

    init(selection: Binding<String?>? = nil) {
        self._selection = selection ?? .constant("browse")
    }

    let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("浏览".localized)
                    .font(.largeTitle.bold())
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                if isLoading {
                    ProgressView("加载中...".localized)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    Text("排行榜".localized)
                        .font(.title2.bold())
                        .padding(.horizontal, 24)

                    // 惰性网格与 Equatable 结合，滚动期间大幅降低计算开销
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(charts) { chart in
                            BrowseChartCard(
                                chart: chart,
                                onSelect: {
                                    selection = "playlist_\(chart.id)"
                                },
                                onPlay: {
                                    playChart(chart)
                                }
                            )
                            .equatable()
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 80)
            }
        }
        .task { await loadCharts() }
    }

    private func loadCharts() async {
        if let cached = BrowseDataCache.shared.cachedData, BrowseDataCache.shared.isFresh {
            if charts.isEmpty {
                charts = cached.charts
            }
            isLoading = false
            return
        }

        if charts.isEmpty {
            isLoading = true
        }
        do {
            let fetched = try await NetworkManager.shared.toplist()
            charts = fetched
            BrowseDataCache.shared.save(charts: fetched)
        } catch {
            print("BrowseView error: \(error)")
        }
        isLoading = false
    }

    private func playChart(_ chart: APIPlaylist) {
        Task {
            do {
                let songs = try await NetworkManager.shared.playlistTracks(id: chart.id, limit: 50)
                if !songs.isEmpty {
                    player.playAll(songs)
                }
            } catch {
                print("加载榜单歌曲失败: \(error)")
            }
        }
    }
}

// MARK: - Browse Chart Card (独立轻量化 Cell，遵循 Equatable 隔绝外部重绘)

struct BrowseChartCard: View, Equatable {
    let chart: APIPlaylist
    var onSelect: (() -> Void)? = nil
    var onPlay: (() -> Void)? = nil

    @Environment(ThemeManager.self) private var themeManager
    @State private var isHovering = false
    @State private var hoverDebounceTask: Task<Void, Never>?
    @State private var isPlayHovering = false
    @State private var isLoadingSongs = false

    static func == (lhs: BrowseChartCard, rhs: BrowseChartCard) -> Bool {
        lhs.chart.id == rhs.chart.id &&
        lhs.chart.name == rhs.chart.name &&
        lhs.chart.displayCover == rhs.chart.displayCover &&
        lhs.chart.playCount == rhs.chart.playCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                // 封面底层：采用纯后台硬解与 Downsampling 的高性能缓存封面 (170x170 pt -> 340x340 px)
                Button {
                    onSelect?()
                } label: {
                    CachedAsyncCoverView(
                        urlString: chart.displayCover,
                        placeholderIcon: "music.note.list",
                        targetSize: 170,
                        cornerRadius: 10,
                        cancelOnDisappear: true
                    )
                    .frame(width: 170, height: 170)
                }
                .buttonStyle(.plain)
                // 常态使用超微阴影，悬停时平滑加深，杜绝大半径模糊产生的离屏渲染损耗
                .shadow(
                    color: .black.opacity(isHovering ? 0.18 : 0.05),
                    radius: isHovering ? 6 : 2,
                    y: isHovering ? 3 : 1
                )
                .scaleEffect(isHovering ? 1.02 : 1.0)

                // 悬停时快捷播放按钮
                if isHovering {
                    Button {
                        handlePlay()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(themeManager.accentColor)
                                .frame(width: 38, height: 38)
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                            if isLoadingSongs {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(x: 1.5)
                            }
                        }
                        .scaleEffect(isPlayHovering ? 1.08 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPlayHovering = h
                        }
                    }
                    .padding(10)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                hoverDebounceTask?.cancel()
                if hovering {
                    hoverDebounceTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 45_000_000) // 45ms 滚动防抖抑制
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isHovering = true
                        }
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHovering = false
                    }
                }
            }

            // 榜单标题与播放量：单行固定布局
            Button {
                onSelect?()
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(chart.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let count = chart.playCount {
                        Text(formatCount(count) + " " + "次播放".localized)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 170)
    }

    private func handlePlay() {
        guard !isLoadingSongs else { return }
        isLoadingSongs = true
        onPlay?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoadingSongs = false
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 {
            return String(format: "%.1f亿", Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: "%.1f万", Double(count) / 10_000)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - 榜单数据常驻内存缓存

@MainActor
final class BrowseDataCache {
    static let shared = BrowseDataCache()
    struct CachePayload {
        let charts: [APIPlaylist]
        let timestamp: Date
    }
    private(set) var cachedData: CachePayload?

    var isFresh: Bool {
        guard let data = cachedData else { return false }
        return Date().timeIntervalSince(data.timestamp) < 600 // 10分钟新鲜期
    }

    func save(charts: [APIPlaylist]) {
        cachedData = CachePayload(charts: charts, timestamp: Date())
    }
}
