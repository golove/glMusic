//
//  NowPlayingService.swift
//  glMusic
//
//  Created by go love on 11/10/26.
//

import AppKit
import MediaPlayer
import CoreImage

/// 系统媒体中心集成服务 (MPNowPlayingInfoCenter & MPRemoteCommandCenter)
@MainActor
final class NowPlayingService {
    static let shared = NowPlayingService()

    private nonisolated static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private init() {}

    /// 更新当前系统媒体控制中心的播放状态与曲目信息
    func update(
        song: APISong?,
        duration: TimeInterval,
        currentTime: TimeInterval,
        isPlaying: Bool
    ) {
        guard let song = song else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.name,
            MPMediaItemPropertyArtist: song.displayArtist,
            MPMediaItemPropertyAlbumTitle: song.displayAlbum,
            MPMediaItemPropertyPlaybackDuration: duration > 0 ? duration : Double(song.durationMs) / 1000.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if let currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo,
           let artwork = currentInfo[MPMediaItemPropertyArtwork] {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// 设置封面艺术图
    func setArtwork(_ nsImage: NSImage) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in nsImage }
        info[MPMediaItemPropertyArtwork] = artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// 异步预生成高斯模糊背景小图 (140x140，单次 GPU 耗时 < 1.5ms，消除全屏实时大模糊滤镜性能损耗)
    nonisolated static func generateBlurredArtwork(from image: NSImage) -> NSImage? {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else { return nil }

        let extent = ciImage.extent
        guard extent.width > 0 && extent.height > 0 else { return nil }

        let targetSize: CGFloat = 140.0
        let scale = targetSize / max(extent.width, extent.height)
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let clamped = scaledImage.clampedToExtent()
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(clamped, forKey: kCIInputImageKey)
        filter.setValue(16.0, forKey: kCIInputRadiusKey)

        guard let output = filter.outputImage else { return nil }
        let cropped = output.cropped(to: CGRect(x: 0, y: 0, width: targetSize, height: targetSize))

        guard let cgImage = ciContext.createCGImage(cropped, from: cropped.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: targetSize, height: targetSize))
    }

    /// 注册系统原生控制中心/锁屏/键盘多媒体按键响应
    func setupRemoteCommands(
        onPlay: @escaping @MainActor () -> Void,
        onPause: @escaping @MainActor () -> Void,
        onToggle: @escaping @MainActor () -> Void,
        onNext: @escaping @MainActor () -> Void,
        onPrevious: @escaping @MainActor () -> Void,
        onSeek: @escaping @MainActor (TimeInterval) -> Void
    ) {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { _ in
            Task { @MainActor in onPlay() }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { _ in
            Task { @MainActor in onPause() }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in onToggle() }
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { _ in
            Task { @MainActor in onNext() }
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { _ in
            Task { @MainActor in onPrevious() }
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in onSeek(posEvent.positionTime) }
            return .success
        }
    }
}
