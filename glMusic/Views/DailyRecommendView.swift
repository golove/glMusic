//
//  DailyRecommendView.swift
//  glMusic
//
//  Created by go love on 10/26/26.
//

import SwiftUI

struct DailyRecommendView: View {
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @State private var songs: [APISong] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

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
        VStack{
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                  

                    if isLoading {
                        ProgressView("加载每日推荐...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                        
                      
                        
                    } else if let error = errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "lock.circle")
                                .font(.system(size: 40))
                                .foregroundStyle(.tertiary)
                            Text(error)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("每日推荐需要登录网易云音乐账号")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else if songs.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note")
                                .font(.system(size: 36))
                                .foregroundStyle(.tertiary)
                            Text("暂无推荐歌曲")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                       

                       

                        // Song List
                        LazyVStack(spacing: 0) {
                            ForEach(Array(songs.enumerated()), id: \.element.id) { idx, song in
                                UnifiedSongRow(
                                    song: song,
                                    index: idx + 1,
                                    allSongs: songs
                                )
                            }
                        }
//                        .padding(.bottom, 80)
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            // 顶部常驻固定导航栏 (不随下方列表滚动)
            VStack{
               
                headerSection
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                // Column headers
                HStack(spacing: 0) {
                    Text("#").frame(width: 36, alignment: .center)
                    Text("标题").frame(maxWidth: .infinity, alignment: .leading)
                    Text("艺人").frame(width: 160, alignment: .leading)
                    Text("专辑").frame(width: 160, alignment: .leading)
                    Image(systemName: "clock").frame(width: 60, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .padding(.bottom, 6)
               
            }
            .frame(height: 200)
            .background(.ultraThinMaterial)
            .zIndex(2)
        }
        
           
        .task { await loadDailySongs() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 24) {
            // Calendar style Artwork
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: themeManager.currentTheme.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 140, height: 140)
                    .shadow(color: themeManager.accentColor.opacity(0.3), radius: 12, y: 6)

                VStack(spacing: 4) {
                    Text(todayWeekday)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .textCase(.uppercase)

                    Text(todayDayNumber)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text("专属推荐")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("每日推荐")
                    .font(.system(size: 28, weight: .bold))

                Text("符合你口味的专属歌单 · 每日 6:00 更新")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Action: Play all & Download
                PlaybackActionBar(
                    songs: songs,
                    playTitle: "播放全部",
                    downloadHelpText: "下载全部推荐歌曲到本地"
                )
                .padding(.bottom, 12)
            }

       
        }
    }

    private func loadDailySongs() async {
        isLoading = true
        errorMessage = nil
        do {
            if !NetworkManager.shared.isLoggedIn {
                errorMessage = "请先登录账号"
            } else {
                songs = try await NetworkManager.shared.dailyRecommendSongs()
            }
        } catch {
            print("加载每日推荐失败: \(error)")
            errorMessage = "获取每日推荐失败，请确认是否已登录"
        }
        isLoading = false
    }
}

#Preview {
    DailyRecommendView()
        .environment(PlayerManager())
        .environment(ThemeManager.shared)
}
