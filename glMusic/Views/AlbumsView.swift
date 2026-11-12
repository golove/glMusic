//
//  AlbumsView.swift
//  glMusic
//
//  Created by go love on 10/23/26.
//

import SwiftUI

struct AlbumsView: View {
    @Binding var selection: String?
    @Environment(PlayerManager.self) private var player
    @State private var albums: [APIAlbumDetail] = []
    @State private var isLoading = true

    let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)]

    init(selection: Binding<String?>? = nil) {
        self._selection = selection ?? .constant("albums")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .lastTextBaseline) {
                    Text("专辑".localized)
                        .font(.largeTitle.bold())
                    Spacer()
                    if !albums.isEmpty {
                        Text(String(format: "%d 张新碟".localized, albums.count))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                if isLoading {
                    ProgressView("加载中...".localized)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // 使用惰性网格容器，保障大数据量下视图按需创建
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(albums) { album in
                            AlbumGridCard(
                                album: album,
                                onSelect: {
                                    selection = "album_\(album.id)"
                                },
                                onPlay: {
                                    playAlbum(album)
                                }
                            )
                            .equatable() // 启用 Equatable 比较，阻断不必要的 body 重复求值
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 80)
            }
        }
        .task { await loadAlbums() }
    }

    private func loadAlbums() async {
        isLoading = true
        do {
            albums = try await NetworkManager.shared.newAlbums(limit: 30)
        } catch {
            print("AlbumsView error: \(error)")
        }
        isLoading = false
    }

    private func playAlbum(_ album: APIAlbumDetail) {
        Task {
            do {
                let detail = try await NetworkManager.shared.albumDetail(id: album.id)
                if let songs = detail.songs, !songs.isEmpty {
                    player.playAll(songs)
                }
            } catch {
                print("加载专辑失败: \(error)")
            }
        }
    }
}

// MARK: - Album Grid Card (独立轻量化 Cell，遵循 Equatable 隔绝外部重绘)

struct AlbumGridCard: View, Equatable {
    let album: APIAlbumDetail
    var onSelect: (() -> Void)? = nil
    var onPlay: (() -> Void)? = nil

    @State private var isHovering = false
    @State private var isLoadingSongs = false

    // MARK: - Equatable 实现 (只在关键元数据变动时刷新 body)
    static func == (lhs: AlbumGridCard, rhs: AlbumGridCard) -> Bool {
        lhs.album.id == rhs.album.id &&
        lhs.album.name == rhs.album.name &&
        lhs.album.coverUrl == rhs.album.coverUrl &&
        lhs.album.picUrl == rhs.album.picUrl &&
        lhs.album.artist?.name == rhs.album.artist?.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                // 强制采用后台硬解与 Downsampling 的高性能缓存封面组件 (170x170 pt -> 340x340 Retina 像素)
                CachedAsyncCoverView(
                    urlString: album.coverUrl ?? album.picUrl,
                    placeholderIcon: "music.note",
                    targetSize: 170,
                    cornerRadius: 10,
                    cancelOnDisappear: true,
                    fixedSize: true
                )
                // 常态使用极低开销轻量阴影，悬停时平滑增强，避免离屏多通道渲染损耗 GPU
                .shadow(
                    color: .black.opacity(isHovering ? 0.16 : 0.04),
                    radius: isHovering ? 6 : 2,
                    y: isHovering ? 3 : 1
                )
                .scaleEffect(isHovering ? 1.02 : 1.0)

                // 悬停播放快捷键
                if isHovering {
                    Button {
                        handlePlay()
                    } label: {
                        ZStack {
                            if isLoadingSongs {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 36, height: 36)
                                    .background(.ultraThinMaterial, in: Circle())
                            } else {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 36))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.5))
                                    .shadow(radius: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .transition(.opacity)
                }
            }
            .onHover { h in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = h
                }
            }
            .onTapGesture {
                onSelect?()
            }

            // 固定文字布局与单行截断，防止文本测量抖动
            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(album.artist?.name ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect?()
            }
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
}

#Preview {
    AlbumsView()
}
