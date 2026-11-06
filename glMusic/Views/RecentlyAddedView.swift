//
//  RecentlyAddedView.swift
//  glMusic
//
//  Created by go love on 10/23/26.
//

import SwiftUI

struct RecentlyAddedView: View {
    @Binding var selection: String?
    @State private var albums: [APIAlbumDetail] = []
    @State private var isLoading = true

    init(selection: Binding<String?>? = nil) {
        self._selection = selection ?? .constant("recent")
    }

    let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("最近添加".localized)
                    .font(.largeTitle.bold())
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
        .task { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        do {
            albums = try await NetworkManager.shared.newAlbums(limit: 20)
        } catch {
            print("RecentlyAddedView error: \(error)")
        }
        isLoading = false
    }
}

#Preview {
    RecentlyAddedView()
}
