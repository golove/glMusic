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
    @State private var downloadManager = DownloadManager.shared

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
                    .help("正在下载: \(Int(progress * 100))%")

                case .downloaded:
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: iconSize))
                        .foregroundStyle(.pink)
                        .help("已下载，支持离线播放 (右键更多操作)")

                case .failed(let err):
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: iconSize))
                        .foregroundStyle(.red)
                        .help("下载失败: \(err) (点击重试)")

                case .waiting:
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: iconSize + 4, height: iconSize + 4)
                        .help("准备下载中...")

                case .notDownloaded:
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: iconSize))
                        .foregroundStyle(.secondary)
                        .help("下载此歌曲到本地")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if downloadManager.isDownloaded(song.id) {
                Button {
                    downloadManager.revealInFinder(song.id)
                } label: {
                    Label("在访达中显示", systemImage: "folder")
                }

                Button {
                    downloadManager.deleteDownload(song.id)
                    downloadManager.downloadSong(song)
                } label: {
                    Label("重新下载", systemImage: "arrow.clockwise")
                }

                Divider()

                Button(role: .destructive) {
                    downloadManager.deleteDownload(song.id)
                } label: {
                    Label("删除已下载文件", systemImage: "trash")
                }
            } else if downloadManager.isDownloading(song.id) {
                Button {
                    downloadManager.cancelDownload(song.id)
                } label: {
                    Label("取消下载", systemImage: "xmark.circle")
                }
            } else {
                Button {
                    downloadManager.downloadSong(song)
                } label: {
                    Label("下载此歌曲", systemImage: "arrow.down.circle")
                }
            }
        }
    }
}
