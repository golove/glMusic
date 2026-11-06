//
//  AlbumsView.swift
//  glMusic
//
//  Created by go love on 10/23/26.
//

import SwiftUI

struct AlbumsView: View {
    @Binding var selection: String?
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
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(albums) { album in
                            AlbumGridCard(album: album) {
                                selection = "album_\(album.id)"
                            }
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
}

// MARK: - Album Grid Card

struct AlbumGridCard: View {
    let album: APIAlbumDetail
    var onSelect: (() -> Void)? = nil
    @Environment(PlayerManager.self) private var player
    @State private var isHovering = false
    @State private var isLoadingSongs = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: album.coverUrl ?? album.picUrl ?? "")) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: Rectangle().fill(.quaternary)
                        .overlay(Image(systemName: "music.note").font(.title).foregroundStyle(.tertiary))
                    }
                }
                .frame(width: 170, height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                .scaleEffect(isHovering ? 1.03 : 1.0)

                // Hover Play Button
                if isHovering {
                    Button {
                        loadAndPlay()
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
                                    .shadow(radius: 4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovering = h } }
            .onTapGesture {
                if let onSelect = onSelect {
                    onSelect()
                } else {
                    loadAndPlay()
                }
            }

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
                if let onSelect = onSelect {
                    onSelect()
                } else {
                    loadAndPlay()
                }
            }
        }
        .frame(width: 170)
    }

    private func loadAndPlay() {
        guard !isLoadingSongs else { return }
        isLoadingSongs = true
        Task {
            do {
                let detail = try await NetworkManager.shared.albumDetail(id: album.id)
                if let songs = detail.songs, !songs.isEmpty {
                    player.playAll(songs)
                }
            } catch {
                print("加载专辑失败: \(error)")
            }
            isLoadingSongs = false
        }
    }
}

#Preview {
    AlbumsView()
}
