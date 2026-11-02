//
//  ArtistsView.swift
//  glMusic
//
//  Created by go love on 10/23/26.
//

import SwiftUI

struct ArtistsView: View {
    @Binding var selection: String?
    @State private var artists: [APIArtistDetail] = []
    @State private var isLoading = true

    init(selection: Binding<String?>? = nil) {
        self._selection = selection ?? .constant("artists")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .lastTextBaseline) {
                    Text("艺人")
                        .font(.largeTitle.bold())
                    Spacer()
                    if !artists.isEmpty {
                        Text("热门艺人")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                if isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    Divider().padding(.horizontal, 24)

                    LazyVStack(spacing: 0) {
                        ForEach(artists) { artist in
                            APIArtistRow(artist: artist) {
                                selection = "artist_\(artist.id)"
                            }
                        }
                    }
                }

                Spacer(minLength: 80)
            }
        }
        .task { await loadArtists() }
    }

    private func loadArtists() async {
        isLoading = true
        do {
            artists = try await NetworkManager.shared.topArtists(limit: 30)
        } catch {
            print("ArtistsView error: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Artist Row

struct APIArtistRow: View {
    let artist: APIArtistDetail
    var onSelect: (() -> Void)? = nil
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: artist.avatarUrl ?? "")) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Circle().fill(.quaternary)
                        .overlay(Text(String(artist.name.prefix(1))).font(.headline).foregroundStyle(.secondary))
                default:
                    Circle().fill(.quaternary)
                        .overlay(ProgressView().controlSize(.mini))
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(artist.name)
                    .font(.system(size: 15, weight: .medium))
                if let albums = artist.albumSize {
                    Text("\(albums) 张专辑")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(isHovered ? Color.primary.opacity(0.04) : .clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            onSelect?()
        }
    }
}

#Preview {
    ArtistsView()
}
