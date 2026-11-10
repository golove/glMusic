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

                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(charts) { chart in
                            PlaylistCard(playlist: chart) {
                                selection = "playlist_\(chart.id)"
                            }
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
