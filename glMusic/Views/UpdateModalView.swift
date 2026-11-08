//
//  UpdateModalView.swift
//  glMusic
//
//  Created by go love on 11/8/26.
//

import SwiftUI
import AppKit

struct UpdateModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @State private var updateManager = UpdateManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerSection
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

            Divider()
                .opacity(0.3)

            // MARK: - Release Notes
            releaseNotesSection
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

            Divider()
                .opacity(0.3)

            // MARK: - Footer Actions
            footerSection
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
        .frame(width: 480, height: 420)
        .background(.regularMaterial)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("发现新版本".localized)
                        .font(.system(size: 18, weight: .bold))

                    Text("glMusic")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(themeManager.accentColor)
                }

                HStack(spacing: 6) {
                    Text("v\(updateManager.currentVersion)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)

                    Text("v\(updateManager.latestRelease?.versionString ?? "")")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(themeManager.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(themeManager.accentColor.opacity(0.12), in: Capsule())
                }
            }

            Spacer()
        }
    }

    // MARK: - Release Notes

    private var releaseNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("更新日志".localized)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            ScrollView {
                Text(formattedReleaseNotes)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 12) {
            // 下载进度条 / 状态提示
            if updateManager.isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: updateManager.downloadProgress, total: 1.0)
                        .tint(themeManager.accentColor)

                    HStack {
                        Text(updateManager.statusMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(Int(updateManager.downloadProgress * 100))%")
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let error = updateManager.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)

                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()
                }
            }

            // 操作按钮
            HStack(spacing: 12) {
                if let release = updateManager.latestRelease, let url = URL(string: release.htmlUrl), updateManager.errorMessage != nil {
                    Button("浏览器下载".localized) {
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(themeManager.accentColor)
                }

                Spacer()

                if updateManager.isDownloading {
                    Button("取消".localized) {
                        updateManager.cancelDownload()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                } else {
                    Button("稍后提醒".localized) {
                        updateManager.showUpdateDialog = false
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button {
                        updateManager.startDownloadAndInstall()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 12))
                            Text(updateManager.errorMessage == nil ? "立即更新并重启".localized : "重试更新".localized)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.accentColor)
                    .controlSize(.regular)
                }
            }
        }
    }

    private var formattedReleaseNotes: String {
        if let body = updateManager.latestRelease?.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return body
        }
        return "包含了常规性能优化与问题修复。".localized
    }
}
