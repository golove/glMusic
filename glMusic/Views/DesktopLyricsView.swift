//
//  DesktopLyricsView.swift
//  glMusic
//
//  Created by go love on 11/10/26.
//

import SwiftUI
import NeteaseCloudMusicAPI

struct DesktopLyricsView: View {
    var manager: DesktopLyricsManager
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var languageManager

    @State private var isHovered: Bool = false
    @State private var resizeStartSize: CGSize? = nil

    var body: some View {
        ZStack {
            // MARK: - 可自定义的自适应背景层
            panelBackground

            VStack(spacing: 4) {
                // MARK: - 悬停控制栏 (仅在未锁定且鼠标悬停或正在配置外观时显现)
                if (isHovered || manager.isShowingSettings) && !manager.isLocked {
                    hoverControlBar
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // MARK: - 双行歌词核心展示区 (独立隔离渲染，避免 100ms 卡拉OK进度刷新触发毛玻璃背景与窗口重绘)
                DesktopLyricsDisplayArea(manager: manager)
                    .allowsHitTesting(false)
                    .padding(.horizontal, 24)
                    .padding(.vertical, (isHovered || manager.isShowingSettings) && !manager.isLocked ? 4 : 8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            // MARK: - 右下角窗口尺寸调节拉手 (未锁定且悬停时可见)
            if isHovered && !manager.isLocked {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 1)
                                    .onChanged { gesture in
                                        guard !manager.isLocked, let panel = manager.panel else { return }
                                        if resizeStartSize == nil {
                                            resizeStartSize = panel.frame.size
                                        }
                                        guard let start = resizeStartSize else { return }
                                        let newW = start.width + gesture.translation.width
                                        let newH = start.height - gesture.translation.height
                                        manager.liveResizePanel(newWidth: newW, newHeight: newH)
                                    }
                                    .onEnded { _ in
                                        resizeStartSize = nil
                                        manager.finishResize()
                                    }
                            )
                            .help("按住拖拽可自由调整歌词窗口宽高".localized)
                            .padding(.bottom, 2)
                            .padding(.trailing, 2)
                    }
                }
            }

            // MARK: - 锁定状态下的悬浮解锁胶囊 (鼠标移入歌词区即可点击解锁)
            if manager.isLocked && manager.showUnlockHandle {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            manager.unlock()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text("点击解锁".localized)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.85), in: Capsule())
                            .overlay(Capsule().stroke(themeManager.accentColor, lineWidth: 1.2))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                        .padding(.trailing, 10)
                    }
                    Spacer()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: manager.showUnlockHandle)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHovered = hovering
            }
        }
    }

    // MARK: - 多样化背景样式渲染

    @ViewBuilder
    private var panelBackground: some View {
        switch manager.backgroundStyle {
        case .transparent:
            // 完全透明模式：未悬停时完全不绘制背景，纯文字与阴影浮于桌面；悬停时提供半透明编辑辅助底色
            if isHovered && !manager.isLocked {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.32))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            } else {
                Color.clear
            }

        case .frosted:
            // 晶透磨砂毛玻璃模式 (默认经典，支持实时透明度调节)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(manager.backgroundOpacity))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(isHovered && !manager.isLocked ? 0.22 : 0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)

        case .dark:
            // 高对比深黑模式
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(manager.backgroundOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)

        case .light:
            // 透亮浅白模式
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(manager.backgroundOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        }
    }

    // MARK: - 悬停控制条

    private var hoverControlBar: some View {
        HStack(spacing: 12) {
            // 拖拽手柄指示
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.65))
                .help("按住任意空白处或手柄即可拖动窗口".localized)

            Spacer()

            // 快捷播控
            Button { player.previous() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button { player.togglePlay() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(themeManager.accentColor)
            }
            .buttonStyle(.plain)

            Button { player.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 10)
                .opacity(0.3)

            // 字号调节
            Button { manager.decreaseFontSize() } label: {
                Text("A-")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .help("调小字号".localized)

            Button { manager.increaseFontSize() } label: {
                Text("A+")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .help("调大字号".localized)

            Divider()
                .frame(height: 10)
                .opacity(0.3)

            // MARK: - 样式与背景调节
            Button {
                manager.toggleSettings()
            } label: {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(manager.isShowingSettings ? themeManager.accentColor : .white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .help("个性化桌面歌词背景与外观设置".localized)

            // 锁定按钮
            Button {
                manager.lock()
            } label: {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .help("锁定桌面歌词 (锁定后鼠标移动到右上角点击即可解锁，也可按 ⇧⌘L)".localized)

            // 关闭按钮
            Button {
                manager.isShowing = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .buttonStyle(.plain)
            .help("隐藏桌面歌词 (⇧⌘D)".localized)
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
    }
}

// MARK: - 独立歌词渲染展示区 (彻底隔离播放进度刷新，保护毛玻璃与窗口背景 0 重绘)

private struct DesktopLyricsDisplayArea: View {
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    var manager: DesktopLyricsManager

    private var currentLyric: LyricLine? {
        guard player.lyrics.indices.contains(player.currentLyricIndex) else {
            return nil
        }
        return player.lyrics[player.currentLyricIndex]
    }

    private var nextLyric: LyricLine? {
        let nextIndex = player.currentLyricIndex + 1
        guard player.lyrics.indices.contains(nextIndex) else {
            return nil
        }
        return player.lyrics[nextIndex]
    }

    var body: some View {
        VStack(spacing: 3) {
            if let current = currentLyric {
                // 第一行：当前歌词 (单层渐变染色，100% 避免错位与双层阴影)
                DesktopKaraokeLine(
                    line: current,
                    fontSize: manager.fontSize,
                    backgroundStyle: manager.backgroundStyle
                )
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)

                // 第二行：译文或下一行预告
                if manager.showTranslation, let trans = current.translation, !trans.isEmpty {
                    Text(trans)
                        .font(.system(size: max(12, manager.fontSize * 0.65), weight: .medium))
                        .foregroundStyle(manager.backgroundStyle == .light ? Color.black.opacity(0.85) : Color.white.opacity(0.85))
                        .lineLimit(1)
                        .shadow(color: manager.backgroundStyle == .light ? .clear : .black.opacity(0.85), radius: 2, x: 0, y: 1)
                } else if let next = nextLyric {
                    Text(next.text)
                        .font(.system(size: max(12, manager.fontSize * 0.65), weight: .medium))
                        .foregroundStyle(manager.backgroundStyle == .light ? Color.black.opacity(0.6) : Color.white.opacity(0.65))
                        .lineLimit(1)
                        .shadow(color: manager.backgroundStyle == .light ? .clear : .black.opacity(0.85), radius: 2, x: 0, y: 1)
                }
            } else if let song = player.currentSong {
                Text(song.name + " - " + song.displayArtist)
                    .font(.system(size: manager.fontSize, weight: .bold))
                    .foregroundStyle(manager.backgroundStyle == .light ? Color.black : Color.white)
                    .shadow(color: manager.backgroundStyle == .light ? .clear : .black.opacity(0.8), radius: 3, x: 0, y: 1)
                    .lineLimit(1)

                Text("正在准备歌词...".localized)
                    .font(.system(size: max(12, manager.fontSize * 0.65), weight: .medium))
                    .foregroundStyle(manager.backgroundStyle == .light ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
            } else {
                Text("glMusic")
                    .font(.system(size: manager.fontSize, weight: .bold))
                    .foregroundStyle(themeManager.accentColor)
                    .shadow(color: manager.backgroundStyle == .light ? .clear : .black.opacity(0.8), radius: 3, x: 0, y: 1)

                Text("优雅的原生音乐播放器".localized)
                    .font(.system(size: max(12, manager.fontSize * 0.65), weight: .medium))
                    .foregroundStyle(manager.backgroundStyle == .light ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
            }
        }
    }
}

// MARK: - 仅单行卡拉OK文字独立监听时间更新 (0 影响父级排版与背景毛玻璃)

private struct DesktopKaraokeLine: View {
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    let line: LyricLine
    let fontSize: CGFloat
    let backgroundStyle: DesktopLyricsBackgroundStyle

    var body: some View {
        let progress = line.progress(at: player.currentTime)

        let baseColor: Color = backgroundStyle == .light ? Color.black.opacity(0.8) : Color.white.opacity(0.85)

        if progress > 0.0 && progress < 1.0 {
            // 水平平滑遮罩裁剪 (0 CoreText 字符串重排，0 材质着色器刷新)
            let safeProgress = min(1.0, max(0.0, progress))

            ZStack(alignment: .leading) {
                Text(line.text)
                    .font(.system(size: fontSize, weight: .heavy))
                    .foregroundStyle(baseColor)
                    .shadow(color: backgroundStyle == .light ? .clear : .black.opacity(0.95), radius: 3, x: 0, y: 1)

                Text(line.text)
                    .font(.system(size: fontSize, weight: .heavy))
                    .foregroundStyle(themeManager.accentColor)
                    .shadow(color: backgroundStyle == .light ? .clear : .black.opacity(0.95), radius: 3, x: 0, y: 1)
                    .mask(alignment: .leading) {
                        GeometryReader { geo in
                            let fillW = geo.size.width * safeProgress
                            let feather: CGFloat = 8
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: max(0, fillW - feather))
                                LinearGradient(
                                    colors: [Color.white, Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: min(feather, fillW))
                            }
                            .frame(width: fillW, alignment: .leading)
                        }
                    }
            }
        } else if progress >= 1.0 {
            // 已唱完 (progress >= 1.0)：全亮主题色静态文本，0 遮罩开销
            Text(line.text)
                .font(.system(size: fontSize, weight: .heavy))
                .foregroundStyle(themeManager.accentColor)
                .shadow(color: backgroundStyle == .light ? .clear : .black.opacity(0.95), radius: 4, x: 0, y: 1)
                .shadow(color: themeManager.accentColor.opacity(0.35), radius: 6, x: 0, y: 0)
        } else {
            // 待播 (progress <= 0)：未激活底色静态文本，0 遮罩开销
            Text(line.text)
                .font(.system(size: fontSize, weight: .heavy))
                .foregroundStyle(baseColor)
                .shadow(color: backgroundStyle == .light ? .clear : .black.opacity(0.95), radius: 3, x: 0, y: 1)
        }
    }
}

struct DesktopLyricsSettingsWindowView: View {
    var manager: DesktopLyricsManager
    var onClose: () -> Void
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 标题栏与关闭
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(themeManager.accentColor)
                    Text("桌面歌词外观设置".localized)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("关闭外观设置 (ESC)".localized)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().opacity(0.3)

            // MARK: - 配置项列表
            VStack(alignment: .leading, spacing: 10) {
                // 1. 背景风格
                VStack(alignment: .leading, spacing: 4) {
                    Text("背景风格".localized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Picker("", selection: Bindable(manager).backgroundStyle) {
                        ForEach(DesktopLyricsBackgroundStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 2. 背景透明度 (全透明模式置灰提示)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("背景透明度".localized)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(manager.backgroundOpacity * 100))%")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(manager.backgroundStyle == .transparent ? .tertiary : .secondary)
                    }

                    Slider(value: Bindable(manager).backgroundOpacity, in: 0.05...0.95)
                        .tint(themeManager.accentColor)
                        .disabled(manager.backgroundStyle == .transparent)
                }
                .opacity(manager.backgroundStyle == .transparent ? 0.4 : 1.0)

                // 3. 窗口宽度微调
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("窗口宽度".localized)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(manager.windowWidth)) pt")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: { manager.windowWidth },
                            set: { manager.setWidth($0) }
                        ),
                        in: 480...1300,
                        step: 10
                    )
                    .tint(themeManager.accentColor)
                }

                // 4. 字号调节
                HStack {
                    Text("歌词字号".localized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 8) {
                        Button {
                            manager.decreaseFontSize()
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 22, height: 20)
                                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)

                        Text("\(Int(manager.fontSize)) pt")
                            .font(.system(size: 11).monospacedDigit())
                            .frame(minWidth: 40)

                        Button {
                            manager.increaseFontSize()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 22, height: 20)
                                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 5. 歌词译文开关
                Toggle("显示歌词翻译 (如有)".localized, isOn: Bindable(manager).showTranslation)
                    .font(.system(size: 11))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Divider().opacity(0.3)
                    .padding(.vertical, 1)

                // 6. 恢复默认位置与尺寸
                HStack {
                    Spacer()
                    Button {
                        manager.resetPositionAndSize()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                            Text("恢复默认位置与尺寸".localized)
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .frame(width: 320, height: 345)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
