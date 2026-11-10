//
//  DownloadButton.swift
//  glMusic
//
//  Created by go love on 10/29/26.
//

import SwiftUI

struct DownloadButton: View {
    let song: APISong
    var iconSize: CGFloat = 12
    var hasContextMenu: Bool = false
    @Environment(ThemeManager.self) private var themeManager
    private var downloadManager: DownloadManager { DownloadManager.shared }

    var body: some View {
        let status = downloadManager.downloadStatus(song.id)

        Button {
            switch status {
            case .downloaded:
                downloadManager.revealInFinder(song.id)
            case .downloading:
                break
            case .waiting, .failed, .notDownloaded:
                downloadManager.downloadSong(song)
            }
        } label: {
            Group {
                switch status {
                case .downloading(let progress):
                    ZStack {
                        ProgressView()
                            .controlSize(.mini)
                    }
                    .frame(width: iconSize + 4, height: iconSize + 4)
                    .help("正在下载: %d%%".localized(with: Int(progress * 100)))

                case .downloaded:
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: iconSize))
                        .foregroundStyle(themeManager.accentColor)
                        .help("已下载，支持离线播放 (右键更多操作)".localized)

                case .failed(let err):
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: iconSize))
                        .foregroundStyle(.red)
                        .help("下载失败: %@ (点击重试)".localized(with: err))

                case .waiting:
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: iconSize + 4, height: iconSize + 4)
                        .help("准备下载中...".localized)

                case .notDownloaded:
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: iconSize))
                        .foregroundStyle(.secondary)
                        .help("下载此歌曲到本地".localized)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(OptionalContextMenuModifier(hasContextMenu: hasContextMenu, song: song))
    }
}

private struct OptionalContextMenuModifier: ViewModifier {
    let hasContextMenu: Bool
    let song: APISong

    @ViewBuilder
    func body(content: Content) -> some View {
        if hasContextMenu {
            content.contextMenu {
                if DownloadManager.shared.isDownloaded(song.id) {
                    Button {
                        DownloadManager.shared.revealInFinder(song.id)
                    } label: {
                        Label("在访达中显示".localized, systemImage: "folder")
                    }

                    Button {
                        DownloadManager.shared.deleteDownload(song.id)
                        DownloadManager.shared.downloadSong(song)
                    } label: {
                        Label("重新下载".localized, systemImage: "arrow.clockwise")
                    }

                    Divider()

                    Button(role: .destructive) {
                        DownloadManager.shared.deleteDownload(song.id)
                    } label: {
                        Label("删除已下载文件".localized, systemImage: "trash")
                    }
                } else if DownloadManager.shared.isDownloading(song.id) {
                    Button {
                        DownloadManager.shared.cancelDownload(song.id)
                    } label: {
                        Label("取消下载".localized, systemImage: "xmark.circle")
                    }
                } else {
                    Button {
                        DownloadManager.shared.downloadSong(song)
                    } label: {
                        Label("下载此歌曲".localized, systemImage: "arrow.down.circle")
                    }
                }
            }
        } else {
            content
        }
    }
}
