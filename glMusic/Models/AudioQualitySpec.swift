//
//  AudioQualitySpec.swift
//  glMusic
//
//  Created by go love on 11/14/26.
//

import Foundation
import NeteaseCloudMusicAPI

/// 发烧级音频质量规格（采样率、位深、码率、文件体积）
public struct AudioQualitySpec: Equatable, Sendable, Codable {
    public var level: String        // "standard", "exhigh", "lossless", "hires", "jymaster"
    public var format: String       // "FLAC", "MP3", "AAC"
    public var bitrate: Int         // e.g. 128000, 320000, 960000, 1411200
    public var sampleRate: Int      // e.g. 44100, 48000, 96000, 192000
    public var bitDepth: Int        // e.g. 16, 24
    public var size: Int64          // 文件体积 (bytes)

    public init(
        level: String = "exhigh",
        format: String = "MP3",
        bitrate: Int = 320000,
        sampleRate: Int = 44100,
        bitDepth: Int = 16,
        size: Int64 = 0
    ) {
        self.level = level
        self.format = format
        self.bitrate = bitrate
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.size = size
    }

    public var isHiRes: Bool {
        let lvl = level.lowercased()
        return lvl == "hires" || lvl == "jymaster" || sampleRate > 48000 || bitDepth > 16 || bitrate > 1200000
    }

    public var isLossless: Bool {
        return isHiRes || level.lowercased() == "lossless" || format.uppercased() == "FLAC" || bitrate >= 800000
    }

    public var badgeTitle: String {
        if isHiRes {
            return "Hi-Res 无损"
        } else if isLossless {
            return "无损"
        } else if bitrate >= 300000 || level == "exhigh" {
            return "320K"
        } else {
            return "128K"
        }
    }

    public var formattedBitrate: String {
        guard bitrate > 0 else { return "动态码率" }
        return "\(bitrate / 1000) kbps"
    }

    public var formattedSampleRate: String {
        let khz = Double(sampleRate) / 1000.0
        if khz.truncatingRemainder(dividingBy: 1.0) == 0 {
            return "\(Int(khz)) kHz"
        } else {
            return String(format: "%.1f kHz", khz)
        }
    }

    public var formattedBitDepth: String {
        return "\(bitDepth)-bit"
    }

    public var formattedSize: String {
        guard size > 0 else { return "" }
        let mb = Double(size) / (1024.0 * 1024.0)
        return String(format: "%.1f MB", mb)
    }

    public var technicalSummary: String {
        if isHiRes {
            return "Hi-Res 无损 \(formattedBitDepth) / \(formattedSampleRate) \(format.uppercased())"
        } else if isLossless {
            return "无损 \(formattedBitDepth) / \(formattedSampleRate) \(format.uppercased())"
        } else {
            return "\(format.uppercased()) \(formattedBitrate)"
        }
    }
}

extension SoundQualityType: Identifiable {
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .standard: return "标准音质".localized
        case .exhigh: return "极高品质".localized
        case .lossless: return "无损音质".localized
        case .hires: return "Hi-Res 无损".localized
        case .jymaster: return "超清母带".localized
        default: return rawValue.uppercased()
        }
    }

    public var subtitle: String {
        switch self {
        case .standard: return "MP3 128 kbps (极省流量)".localized
        case .exhigh: return "MP3 320 kbps (高清晰度)".localized
        case .lossless: return "FLAC 16-bit / 44.1 kHz (CD级纯正)".localized
        case .hires: return "FLAC 24-bit / 最高 192 kHz (录音室母带)".localized
        case .jymaster: return "Master 24-bit (超清母带)".localized
        default: return "高解析音频"
        }
    }

    public var badgeTitle: String {
        switch self {
        case .standard: return "128K"
        case .exhigh: return "320K"
        case .lossless: return "无损"
        case .hires: return "Hi-Res"
        case .jymaster: return "母带"
        default: return "HD"
        }
    }

    public var isHiRes: Bool {
        return self == .hires || self == .jymaster
    }

    public var isLossless: Bool {
        return self == .lossless || self == .hires || self == .jymaster
    }
}
