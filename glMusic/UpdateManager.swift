//
//  UpdateManager.swift
//  glMusic
//
//  Created by go love on 11/8/26.
//

import SwiftUI
import Foundation
import AppKit

// MARK: - Models

struct GitHubRelease: Codable, Identifiable {
    var id: String { tagName }
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String
    let publishedAt: String?
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case assets
    }

    var versionString: String {
        tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    var zipAsset: GitHubAsset? {
        assets.first { $0.name.lowercased().hasSuffix(".zip") }
    }

    var dmgAsset: GitHubAsset? {
        assets.first { $0.name.lowercased().hasSuffix(".dmg") }
    }
}

struct GitHubAsset: Codable {
    let name: String
    let size: Int
    let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case size
        case browserDownloadUrl = "browser_download_url"
    }
}

// MARK: - Update Manager

@MainActor
@Observable
final class UpdateManager {
    static let shared = UpdateManager()

    var isChecking: Bool = false
    var showUpdateDialog: Bool = false
    var latestRelease: GitHubRelease? = nil

    var isDownloading: Bool = false
    var downloadProgress: Double = 0.0
    var downloadedBytes: Int64 = 0
    var totalBytes: Int64 = 0
    var statusMessage: String = ""
    var errorMessage: String? = nil

    // 手动检查时若已是最新版本弹出的提示
    var showUpToDateAlert: Bool = false

    private let repoOwner = "golove"
    private let repoName = "glMusic"
    private var downloadTask: URLSessionDownloadTask?
    private var downloadDelegate: UpdateDownloadDelegate?

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private init() {}

    /// 检查 GitHub Releases 是否有新版本
    /// - Parameter isUserInitiated: 是否为用户主动点击（手动检查）。后台检查时会节流以避免消耗 GitHub 配额。
    func checkForUpdates(isUserInitiated: Bool = false) async {
        guard !isChecking else { return }

        // 非用户主动发起的检查，控制 4 小时间隔
        if !isUserInitiated {
            let lastCheck = UserDefaults.standard.object(forKey: "last_update_check_time") as? Date ?? .distantPast
            if Date().timeIntervalSince(lastCheck) < 4 * 3600 {
                return
            }
        }

        isChecking = true
        errorMessage = nil

        do {
            let apiURL = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
            var request = URLRequest(url: apiURL)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.setValue("glMusic/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                if isUserInitiated {
                    errorMessage = "检查更新失败，请稍后重试".localized
                }
                isChecking = false
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            UserDefaults.standard.set(Date(), forKey: "last_update_check_time")

            let newVer = release.versionString
            let curVer = currentVersion

            if Self.isVersion(newVer, greaterThan: curVer) {
                self.latestRelease = release
                self.showUpdateDialog = true
            } else if isUserInitiated {
                self.showUpToDateAlert = true
            }
        } catch {
            print("检查更新异常: \(error)")
            if isUserInitiated {
                self.errorMessage = String(format: "%@: %@", "检查更新失败".localized, error.localizedDescription)
            }
        }

        isChecking = false
    }

    /// 开始下载并自动替换重启
    func startDownloadAndInstall() {
        guard let release = latestRelease, let asset = release.zipAsset ?? release.dmgAsset else {
            errorMessage = "未找到可供安装的更新文件".localized
            return
        }

        guard let downloadURL = URL(string: asset.browserDownloadUrl) else {
            errorMessage = "下载地址无效".localized
            return
        }

        isDownloading = true
        downloadProgress = 0.0
        downloadedBytes = 0
        totalBytes = Int64(asset.size)
        statusMessage = "正在连接下载服务器...".localized
        errorMessage = nil

        let delegate = UpdateDownloadDelegate()
        self.downloadDelegate = delegate

        delegate.onProgress = { [weak self] progress, current, total in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.downloadProgress = progress
                self.downloadedBytes = current
                self.totalBytes = total
                self.statusMessage = String(
                    format: "%@ (%@ / %@)".localized,
                    "正在下载更新包".localized,
                    self.formatBytes(current),
                    self.formatBytes(total)
                )
            }
        }

        delegate.onComplete = { [weak self] localURL, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let error = error {
                    self.isDownloading = false
                    self.errorMessage = String(format: "%@: %@", "下载更新失败".localized, error.localizedDescription)
                    return
                }

                guard let localURL = localURL else {
                    self.isDownloading = false
                    self.errorMessage = "下载文件为空".localized
                    return
                }

                self.statusMessage = "正在解压并准备安装...".localized

                Task.detached(priority: .userInitiated) {
                    await self.processAndRelaunch(downloadedFile: localURL, isZip: asset.name.lowercased().hasSuffix(".zip"))
                }
            }
        }

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.downloadTask(with: downloadURL)
        self.downloadTask = task
        task.resume()
    }

    /// 取消下载
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        statusMessage = ""
    }

    /// 解压安装包、替换旧应用并重启
    private nonisolated func processAndRelaunch(downloadedFile: URL, isZip: Bool) async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("glMusic_update_\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let extractDir = tempDir.appendingPathComponent("extracted")
            try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

            var extractedAppURL: URL?

            if isZip {
                // 使用 macOS 原生 ditto 解压 zip 包
                let ditto = Process()
                ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                ditto.arguments = ["-x", "-k", downloadedFile.path, extractDir.path]
                try ditto.run()
                ditto.waitUntilExit()

                let appCandidate = extractDir.appendingPathComponent("glMusic.app")
                if FileManager.default.fileExists(atPath: appCandidate.path) {
                    extractedAppURL = appCandidate
                } else {
                    let contents = try FileManager.default.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil)
                    extractedAppURL = contents.first { $0.pathExtension == "app" }
                }
            } else {
                // 如果是 DMG，使用 hdiutil 挂载提取
                let mountDir = tempDir.appendingPathComponent("mount")
                try FileManager.default.createDirectory(at: mountDir, withIntermediateDirectories: true)

                let hdiutil = Process()
                hdiutil.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                hdiutil.arguments = ["attach", downloadedFile.path, "-nobrowse", "-mountpoint", mountDir.path]
                try hdiutil.run()
                hdiutil.waitUntilExit()

                let appCandidate = mountDir.appendingPathComponent("glMusic.app")
                if FileManager.default.fileExists(atPath: appCandidate.path) {
                    let copiedApp = extractDir.appendingPathComponent("glMusic.app")
                    let ditto = Process()
                    ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                    ditto.arguments = [appCandidate.path, copiedApp.path]
                    try ditto.run()
                    ditto.waitUntilExit()
                    extractedAppURL = copiedApp
                }

                // 卸载挂载点
                let detach = Process()
                detach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                detach.arguments = ["detach", mountDir.path, "-force"]
                try? detach.run()
            }

            guard let newApp = extractedAppURL, FileManager.default.fileExists(atPath: newApp.path) else {
                await MainActor.run {
                    self.isDownloading = false
                    self.errorMessage = "安装包内未找到有效的 glMusic.app".localized
                }
                return
            }

            // 确定目标安装路径（若在 Xcode DerivedData 调试环境下，优先更新 /Applications/glMusic.app）
            var targetAppURL = Bundle.main.bundleURL
            if targetAppURL.path.contains("DerivedData") {
                let standardApp = URL(fileURLWithPath: "/Applications/glMusic.app")
                if FileManager.default.fileExists(atPath: standardApp.path) {
                    targetAppURL = standardApp
                }
            }

            await MainActor.run {
                self.statusMessage = "更新完成，正在重启应用...".localized
            }

            // 编写独立的自替换并重启脚本
            let scriptContent = """
            #!/bin/bash
            TARGET_PID=$1
            NEW_APP="$2"
            TARGET_APP="$3"
            TEMP_DIR="$4"

            # 1. 等待当前进程完全退出
            for i in {1..30}; do
                if ! kill -0 "$TARGET_PID" 2>/dev/null; then
                    break
                fi
                sleep 0.2
            done

            if kill -0 "$TARGET_PID" 2>/dev/null; then
                kill -9 "$TARGET_PID" 2>/dev/null || true
                sleep 0.3
            fi

            # 2. 去除新 app 的 quarantine 隔离标记，防止 macOS 弹出无法打开警告
            xattr -dr com.apple.quarantine "$NEW_APP" 2>/dev/null || true

            # 3. 覆盖替换应用
            rm -rf "$TARGET_APP" 2>/dev/null
            ditto "$NEW_APP" "$TARGET_APP" 2>/dev/null || cp -R "$NEW_APP" "$TARGET_APP" 2>/dev/null
            xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true

            # 4. 重新启动应用
            open -n "$TARGET_APP"

            # 5. 清理临时下载文件
            rm -rf "$TEMP_DIR" 2>/dev/null || true
            """

            let scriptURL = tempDir.appendingPathComponent("update_and_relaunch.sh")
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            let relaunchProcess = Process()
            relaunchProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
            relaunchProcess.arguments = [
                scriptURL.path,
                "\(ProcessInfo.processInfo.processIdentifier)",
                newApp.path,
                targetAppURL.path,
                tempDir.path
            ]
            try relaunchProcess.run()

            // 优雅退出当前应用
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NSApp.terminate(nil)
                }
            }
        } catch {
            await MainActor.run {
                self.isDownloading = false
                self.errorMessage = String(format: "%@: %@", "安装更新失败".localized, error.localizedDescription)
            }
        }
    }

    /// 比较两个语义化版本号，若 v1 > v2 则返回 true
    static func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        let p1 = v1.split(separator: ".").compactMap { Int($0) }
        let p2 = v2.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(p1.count, p2.count)
        for i in 0..<maxCount {
            let n1 = i < p1.count ? p1[i] : 0
            let n2 = i < p2.count ? p2[i] : 0
            if n1 > n2 { return true }
            if n1 < n2 { return false }
        }
        return false
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Download Delegate

private final class UpdateDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    var onProgress: ((Double, Int64, Int64) -> Void)?
    var onComplete: ((URL?, Error?) -> Void)?

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            onProgress?(progress, totalBytesWritten, totalBytesExpectedToWrite)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("update_\(UUID().uuidString).zip")
        do {
            try FileManager.default.moveItem(at: location, to: tempFile)
            onComplete?(tempFile, nil)
        } catch {
            onComplete?(nil, error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            onComplete?(nil, error)
        }
    }
}
