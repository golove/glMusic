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
    let id: Int?
    let name: String
    let size: Int
    let url: String?
    let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case size
        case url
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
    func startDownloadAndInstall(useFallbackBrowserUrl: Bool = false) {
        guard let release = latestRelease, let asset = release.zipAsset ?? release.dmgAsset else {
            errorMessage = "未找到可供安装的更新文件".localized
            return
        }

        let isZip = asset.name.lowercased().hasSuffix(".zip")
        let isDmg = asset.name.lowercased().hasSuffix(".dmg")
        let fileExt = isZip ? "zip" : (isDmg ? "dmg" : (URL(string: asset.name)?.pathExtension ?? "zip"))

        var request: URLRequest
        if !useFallbackBrowserUrl, let assetUrlString = asset.url, let assetApiUrl = URL(string: assetUrlString) {
            request = URLRequest(url: assetApiUrl)
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        } else if !useFallbackBrowserUrl, let assetId = asset.id, let assetApiUrl = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/assets/\(assetId)") {
            request = URLRequest(url: assetApiUrl)
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        } else if let browserUrl = URL(string: asset.browserDownloadUrl) {
            request = URLRequest(url: browserUrl)
        } else {
            errorMessage = "下载地址无效".localized
            return
        }

        request.setValue("glMusic/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 120

        isDownloading = true
        downloadProgress = 0.0
        downloadedBytes = 0
        totalBytes = Int64(asset.size)
        statusMessage = "正在连接下载服务器...".localized
        errorMessage = nil

        let delegate = UpdateDownloadDelegate(fileExtension: fileExt)
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
                    // 如果使用 API 路线失败，且尚未尝试过浏览器直链，自动降级尝试浏览器路线
                    if !useFallbackBrowserUrl, URL(string: asset.browserDownloadUrl) != nil {
                        print("API 资产下载失败 (\(error.localizedDescription))，自动尝试备用下载路线...")
                        self.startDownloadAndInstall(useFallbackBrowserUrl: true)
                        return
                    }

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
                    await self.processAndRelaunch(downloadedFile: localURL, isZip: isZip)
                }
            }
        }

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.downloadTask(with: request)
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
        defer {
            // 清理已下载的原始临时包
            try? FileManager.default.removeItem(at: downloadedFile)
        }

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

                extractedAppURL = self.findAppBundle(in: extractDir)
            } else {
                // 如果是 DMG，使用 hdiutil 挂载提取
                let mountDir = tempDir.appendingPathComponent("mount")
                try FileManager.default.createDirectory(at: mountDir, withIntermediateDirectories: true)

                let hdiutil = Process()
                hdiutil.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                hdiutil.arguments = ["attach", downloadedFile.path, "-nobrowse", "-noverify", "-noautofsck", "-mountpoint", mountDir.path]
                try hdiutil.run()
                hdiutil.waitUntilExit()

                if let appCandidate = self.findAppBundle(in: mountDir) {
                    let copiedApp = extractDir.appendingPathComponent("glMusic.app")
                    let ditto = Process()
                    ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                    ditto.arguments = [appCandidate.path, copiedApp.path]
                    try ditto.run()
                    ditto.waitUntilExit()
                    extractedAppURL = self.findAppBundle(in: extractDir)
                }

                // 卸载挂载点
                let detach = Process()
                detach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                detach.arguments = ["detach", mountDir.path, "-force"]
                try? detach.run()
                detach.waitUntilExit()
            }

            guard let newApp = extractedAppURL, self.isValidAppBundle(at: newApp) else {
                await MainActor.run {
                    self.isDownloading = false
                    self.errorMessage = "安装包内未找到有效的 glMusic.app".localized
                }
                return
            }

            // 确定目标安装路径（若在 Xcode DerivedData 调试环境下，优先更新 /Applications/glMusic.app）
            var targetAppURL = Bundle.main.bundleURL
            if targetAppURL.path.contains("DerivedData") {
                targetAppURL = URL(fileURLWithPath: "/Applications/glMusic.app")
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
            open -n "$TARGET_APP" 2>/dev/null || open "$TARGET_APP"

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

    /// 在指定目录下查找合法的 .app bundle
    private nonisolated func findAppBundle(in directory: URL) -> URL? {
        // 1. 直属 glMusic.app
        let directCandidate = directory.appendingPathComponent("glMusic.app")
        if isValidAppBundle(at: directCandidate) {
            return directCandidate
        }

        // 2. 检查直属同级的所有 .app 目录
        if let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for item in contents where item.pathExtension == "app" {
                if isValidAppBundle(at: item) {
                    return item
                }
            }
        }

        // 3. 递归遍历子目录查找（应对多层压缩目录结构）
        if let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "app" && isValidAppBundle(at: fileURL) {
                    return fileURL
                }
            }
        }

        return nil
    }

    /// 校验是否是结构完整的 macOS App Bundle
    private nonisolated func isValidAppBundle(at url: URL) -> Bool {
        let infoPlist = url.appendingPathComponent("Contents/Info.plist")
        let macosDir = url.appendingPathComponent("Contents/MacOS")
        return FileManager.default.fileExists(atPath: infoPlist.path) &&
               FileManager.default.fileExists(atPath: macosDir.path)
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
    let fileExtension: String

    private var hasCompleted = false
    private let lock = NSLock()

    init(fileExtension: String = "zip") {
        self.fileExtension = fileExtension
        super.init()
    }

    private func notifyComplete(url: URL?, error: Error?) {
        lock.lock()
        defer { lock.unlock() }
        guard !hasCompleted else { return }
        hasCompleted = true
        onComplete?(url, error)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            onProgress?(progress, totalBytesWritten, totalBytesExpectedToWrite)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 1. 校验 HTTP 状态码
        if let httpResponse = downloadTask.response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let statusCode = httpResponse.statusCode
            let desc = statusCode == 504 ? "下载服务器连接超时 (504)，请重试".localized : String(format: "服务器响应错误 (HTTP %d)".localized, statusCode)
            let error = NSError(domain: "UpdateManager", code: statusCode, userInfo: [NSLocalizedDescriptionKey: desc])
            notifyComplete(url: nil, error: error)
            return
        }

        // 2. 校验文件大小及是否为 HTML 错误页面
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: location.path)[.size] as? Int64) ?? 0
        if fileSize < 50_000 {
            let isHtml = (try? String(contentsOf: location, encoding: .utf8))?.contains("<html") ?? false
            let desc = isHtml ? "下载服务器网关超时或网络异常，请重试".localized : "下载文件损坏或不完整".localized
            let error = NSError(domain: "UpdateManager", code: -1001, userInfo: [NSLocalizedDescriptionKey: desc])
            notifyComplete(url: nil, error: error)
            return
        }

        // 3. 移动到临时文件，保留实际格式后缀
        let ext = fileExtension.isEmpty ? "zip" : fileExtension
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("update_\(UUID().uuidString).\(ext)")
        do {
            try FileManager.default.moveItem(at: location, to: tempFile)
            notifyComplete(url: tempFile, error: nil)
        } catch {
            notifyComplete(url: nil, error: error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            notifyComplete(url: nil, error: error)
        }
    }
}
