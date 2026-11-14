//
//  AudioQualityBadgeView.swift
//  glMusic
//
//  Created by go love on 11/14/26.
//

import SwiftUI
import NeteaseCloudMusicAPI

/// Apple Music & Apple Music Classical 风格发烧级音频质量与 Hi-Res 专属徽标
struct AudioQualityBadgeView: View {
    var compact: Bool = false
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @State private var showQualityPopover: Bool = false
    @State private var isHovering: Bool = false

    private var activeSpec: AudioQualitySpec {
        player.currentAudioSpec ?? AudioQualitySpec(
            level: player.soundQuality.rawValue,
            format: (player.soundQuality == .hires || player.soundQuality == .lossless) ? "FLAC" : "MP3",
            bitrate: player.soundQuality == .hires ? 1411200 : (player.soundQuality == .lossless ? 960000 : (player.soundQuality == .exhigh ? 320000 : 128000)),
            sampleRate: player.soundQuality == .hires ? 96000 : 44100,
            bitDepth: player.soundQuality == .hires ? 24 : 16,
            size: 0
        )
    }

    var body: some View {
        Button {
            showQualityPopover.toggle()
        } label: {
            badgePill
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .popover(isPresented: $showQualityPopover, arrowEdge: .bottom) {
            AudioQualityPopoverView(spec: activeSpec)
        }
        .help("点击查看音频详细规格与切换音质".localized)
    }

    // MARK: - 徽标外观渲染 (Hi-Res 金标 / 无损银标 / 320K / 128K)

    @ViewBuilder
    private var badgePill: some View {
        let isHiRes = activeSpec.isHiRes || player.soundQuality.isHiRes
        let isLossless = activeSpec.isLossless || player.soundQuality.isLossless

        HStack(spacing: compact ? 3 : 5) {
            if isHiRes {
                Image(systemName: "sparkles")
                    .font(.system(size: compact ? 8 : 10, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.90, blue: 0.50), Color(red: 0.98, green: 0.70, blue: 0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else if isLossless {
                Image(systemName: "waveform")
                    .font(.system(size: compact ? 8 : 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Text(isHiRes ? "Hi-Res" : (isLossless ? "无损".localized : (activeSpec.bitrate >= 300000 ? "320K" : "128K")))
                .font(.system(size: compact ? 9 : 11, weight: .heavy, design: .rounded))
                .foregroundStyle(isHiRes ? Color(red: 1.0, green: 0.88, blue: 0.52) : (isLossless ? .white : .secondary))
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2 : 3.5)
        .background {
            if isHiRes {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.82, blue: 0.35).opacity(0.26),
                                Color(red: 0.92, green: 0.60, blue: 0.15).opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.90, blue: 0.55).opacity(0.85),
                                        Color(red: 0.95, green: 0.65, blue: 0.25).opacity(0.40)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.9
                            )
                    )
                    .shadow(color: Color.orange.opacity(0.35), radius: isHovering ? 6 : 3, y: 1)
            } else if isLossless {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(isHovering ? 0.6 : 0.35), lineWidth: 0.8)
                    )
            } else {
                Capsule()
                    .fill(.quaternary)
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(isHovering ? 0.3 : 0.15), lineWidth: 0.8)
                    )
            }
        }
        .scaleEffect(isHovering ? 1.04 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
    }
}

// MARK: - Apple Music 风格发烧级音频规格与音质切换弹窗

private struct AudioQualityPopoverView: View {
    let spec: AudioQualitySpec
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager

    private let availableTiers: [SoundQualityType] = [
        .hires,
        .lossless,
        .exhigh,
        .standard
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(spec.isHiRes ? Color.orange.opacity(0.18) : (spec.isLossless ? Color.blue.opacity(0.18) : Color.gray.opacity(0.18)))
                        .frame(width: 36, height: 36)

                    Image(systemName: spec.isHiRes ? "sparkles" : (spec.isLossless ? "waveform.badge.magnifyingglass" : "music.note"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(spec.isHiRes ? Color(red: 1.0, green: 0.78, blue: 0.28) : (spec.isLossless ? themeManager.accentColor : .secondary))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(spec.isHiRes ? "Hi-Res 高解析度无损".localized : (spec.isLossless ? "CD 级纯净无损".localized : "高保真音频".localized))
                        .font(.system(size: 14, weight: .bold))

                    Text(spec.technicalSummary)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Specs Card
            VStack(spacing: 6) {
                specRow(label: "音频编码格式".localized, value: spec.format.uppercased())
                specRow(label: "声音采样率".localized, value: spec.formattedSampleRate)
                specRow(label: "量化位深".localized, value: spec.formattedBitDepth)
                specRow(label: "实时码率".localized, value: spec.formattedBitrate)
                if spec.size > 0 {
                    specRow(label: "音频文件大小".localized, value: spec.formattedSize)
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

            // Audiophile Advice Note
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: spec.isHiRes ? "headphones" : "info.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(spec.isHiRes ? Color.orange : .secondary)

                Text(
                    spec.isHiRes
                    ? "Hi-Res 音轨保留了完整的母带声音动态与空气感。推荐搭配支持高解析度输出的外接 DAC 解码器或耳放聆听。".localized
                    : (spec.isLossless
                       ? "无损音轨采用 FLAC 无损压缩，完整还原录音室原始母带声效，无任何听觉信息丢失。".localized
                       : "压缩音轨兼顾了极速缓冲与清晰音质，适合移动网络或日常轻度聆听。".localized)
                )
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)

            Divider()

            // Quality Tier Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("音质档位设置".localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                ForEach(availableTiers) { tier in
                    Button {
                        if player.soundQuality != tier {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                player.soundQuality = tier
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(tier.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(player.soundQuality == tier ? themeManager.accentColor : .primary)

                                    if tier.isHiRes {
                                        Text("HI-RES")
                                            .font(.system(size: 8, weight: .black, design: .rounded))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.orange.opacity(0.2), in: Capsule())
                                            .foregroundStyle(Color.orange)
                                    }
                                }

                                Text(tier.subtitle)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if player.soundQuality == tier {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(themeManager.accentColor)
                            } else {
                                Circle()
                                    .strokeBorder(.secondary.opacity(0.35), lineWidth: 1.2)
                                    .frame(width: 15, height: 15)
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(
                            player.soundQuality == tier ? themeManager.accentColor.opacity(0.08) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func specRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }
}
