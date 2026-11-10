//
//  LyricsStyleSettingsView.swift
//  glMusic
//
//  Created by go love on 11/8/26.
//

import SwiftUI

/// 歌词对齐方式
enum LyricsAlignment: String, CaseIterable, Identifiable {
    case leading = "leading"
    case center = "center"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leading: return "居左".localized
        case .center: return "居中".localized
        }
    }

    var iconName: String {
        switch self {
        case .leading: return "text.alignleft"
        case .center: return "text.aligncenter"
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        }
    }

    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        }
    }
}

/// 歌词字号档位
enum LyricsFontSize: String, CaseIterable, Identifiable {
    case standard = "standard"
    case large = "large"
    case huge = "huge"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "标准".localized
        case .large: return "放大".localized
        case .huge: return "巨幕".localized
        }
    }

    var activeFontSize: CGFloat {
        switch self {
        case .standard: return 24
        case .large: return 30
        case .huge: return 36
        }
    }

    var inactiveFontSize: CGFloat {
        switch self {
        case .standard: return 20
        case .large: return 24
        case .huge: return 28
        }
    }

    var activeTranslationSize: CGFloat {
        switch self {
        case .standard: return 18
        case .large: return 22
        case .huge: return 26
        }
    }

    var inactiveTranslationSize: CGFloat {
        switch self {
        case .standard: return 15
        case .large: return 18
        case .huge: return 21
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .standard: return 14
        case .large: return 18
        case .huge: return 24
        }
    }
}

/// 歌词动效模式
enum LyricsAnimationMode: String, CaseIterable, Identifiable {
    case karaoke = "karaoke"
    case spotlight = "spotlight"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .karaoke: return "逐字动效".localized
        case .spotlight: return "聚光灯".localized
        }
    }

    var iconName: String {
        switch self {
        case .karaoke: return "sparkles"
        case .spotlight: return "light.beacon.max"
        }
    }
}

/// 歌词显示样式持久化管理器
@Observable @MainActor
final class LyricsStyleManager {
    static let shared = LyricsStyleManager()

    var alignment: LyricsAlignment {
        didSet { UserDefaults.standard.set(alignment.rawValue, forKey: "lyrics_alignment") }
    }

    var fontSize: LyricsFontSize {
        didSet { UserDefaults.standard.set(fontSize.rawValue, forKey: "lyrics_font_size") }
    }

    var animationMode: LyricsAnimationMode {
        didSet { UserDefaults.standard.set(animationMode.rawValue, forKey: "lyrics_animation_mode") }
    }

    var isDepthBlurEnabled: Bool {
        didSet { UserDefaults.standard.set(isDepthBlurEnabled, forKey: "lyrics_depth_blur") }
    }

    var isTranslationEnabled: Bool {
        didSet { UserDefaults.standard.set(isTranslationEnabled, forKey: "lyrics_show_translation") }
    }

    var isEdgeFadeEnabled: Bool {
        didSet { UserDefaults.standard.set(isEdgeFadeEnabled, forKey: "lyrics_edge_fade") }
    }

    private init() {
        let alignRaw = UserDefaults.standard.string(forKey: "lyrics_alignment") ?? LyricsAlignment.leading.rawValue
        self.alignment = LyricsAlignment(rawValue: alignRaw) ?? .leading

        let sizeRaw = UserDefaults.standard.string(forKey: "lyrics_font_size") ?? LyricsFontSize.standard.rawValue
        self.fontSize = LyricsFontSize(rawValue: sizeRaw) ?? .standard

        let modeRaw = UserDefaults.standard.string(forKey: "lyrics_animation_mode") ?? LyricsAnimationMode.karaoke.rawValue
        self.animationMode = LyricsAnimationMode(rawValue: modeRaw) ?? .karaoke

        self.isDepthBlurEnabled = UserDefaults.standard.object(forKey: "lyrics_depth_blur") as? Bool ?? true
        self.isTranslationEnabled = UserDefaults.standard.object(forKey: "lyrics_show_translation") as? Bool ?? true
        self.isEdgeFadeEnabled = UserDefaults.standard.object(forKey: "lyrics_edge_fade") as? Bool ?? true
    }
}

/// 放置在 LyricsView 顶栏的歌词样式配置按钮
struct LyricsStyleButton: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var showPopover = false
    @State private var isHovered = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Image(systemName: "textformat.size")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    showPopover ? themeManager.accentColor : (isHovered ? .white : .white.opacity(0.8))
                )
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("歌词显示样式".localized)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            LyricsStyleSettingsPopover()
        }
    }
}

/// 歌词显示样式配置弹窗
struct LyricsStyleSettingsPopover: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlayerManager.self) private var player
    private var styleManager = LyricsStyleManager.shared

    private var isWordSynced: Bool {
        player.lyrics.contains(where: { $0.isWordSynced })
    }

    var body: some View {
        @Bindable var mgr = styleManager

        VStack(alignment: .leading, spacing: 14) {
            // 头部
            HStack(spacing: 8) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeManager.accentColor)

                Text("歌词显示样式".localized)
                    .font(.headline)

                Spacer()
            }

            Divider()

            // 1. 对齐方式
            VStack(alignment: .leading, spacing: 6) {
                Text("文本对齐".localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Picker("文本对齐".localized, selection: $mgr.alignment) {
                    ForEach(LyricsAlignment.allCases) { item in
                        Label(item.title, systemImage: item.iconName)
                            .tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            // 2. 字号规格
            VStack(alignment: .leading, spacing: 6) {
                Text("字号大小".localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Picker("字号大小".localized, selection: $mgr.fontSize) {
                    ForEach(LyricsFontSize.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            // 3. 动效模式
            VStack(alignment: .leading, spacing: 6) {
                Text("动效模式".localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Picker("动效模式".localized, selection: $mgr.animationMode) {
                    ForEach(LyricsAnimationMode.allCases) { item in
                        Label(item.title, systemImage: item.iconName)
                            .tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if mgr.animationMode == .karaoke {
                    HStack(spacing: 5) {
                        Image(systemName: isWordSynced ? "checkmark.circle.fill" : "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(isWordSynced ? themeManager.accentColor : .secondary)

                        Text(isWordSynced ? "已匹配官方毫秒级逐字时间轴".localized : "当前歌曲使用标准歌词进行平滑渲染".localized)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            }

            Divider()

            // 4. 细节动效与开关
            VStack(alignment:.leading,spacing: 10) {
                Toggle(isOn: $mgr.isDepthBlurEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("景深虚焦效果".localized)
                            .font(.system(size: 13, weight: .medium))
                        Text("非当前行随距离自然失焦虚化".localized)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: $mgr.isTranslationEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("显示外语翻译".localized)
                            .font(.system(size: 13, weight: .medium))
                        Text("双语对照显示".localized)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: $mgr.isEdgeFadeEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("上下边缘渐隐".localized)
                            .font(.system(size: 13, weight: .medium))
                        Text("顶部与底部平滑羽化过渡".localized)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
        }
        .padding(16)
        .frame(width: 270)
    }
}

/// 逐字卡拉OK动效歌词单行组件
struct KaraokeLyricLineView: View {
    @Environment(ThemeManager.self) private var themeManager

    let text: String
    let isActive: Bool
    let progress: Double
    let font: Font
    let textAlignment: TextAlignment
    var inactiveColor: Color
    var customGradient: [Color]?

    init(
        text: String,
        isActive: Bool,
        progress: Double,
        font: Font,
        textAlignment: TextAlignment,
        activeColor: Color? = nil,
        inactiveColor: Color = Color.white.opacity(0.35),
        glowColor: Color? = nil,
        customGradient: [Color]? = nil
    ) {
        self.text = text
        self.isActive = isActive
        self.progress = progress
        self.font = font
        self.textAlignment = textAlignment
        self.inactiveColor = inactiveColor
        self.customGradient = customGradient
    }

    private var activeGradient: LinearGradient {
        if let custom = customGradient, !custom.isEmpty {
            return LinearGradient(
                colors: custom,
                startPoint: .top,
                endPoint: .bottom
            )
        }
        // 顶部高光亮白过渡到淡化约 60% 的柔和主题渐变色彩，纯文字渐变，清澈透亮不刺眼
        return themeManager.lyricSoftGradient
    }

    var body: some View {
        if isActive && progress > 0.0 && progress < 1.0 {
            // 逐字演唱进行中：底层暗色文本 + 顶层主题色遮罩裁剪（0 CoreText 字符串排版重构，0 渐变材质重构）
            let safeProgress = min(1.0, max(0.0, progress))
            ZStack(alignment: .leading) {
                Text(text)
                    .font(font)
                    .multilineTextAlignment(textAlignment)
                    .foregroundStyle(inactiveColor)

                Text(text)
                    .font(font)
                    .multilineTextAlignment(textAlignment)
                    .foregroundStyle(themeManager.accentColor)
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
        } else if isActive && progress >= 1.0 {
            // 本行已唱完：直接显示全亮主题色静态文本，0 渐变开销
            Text(text)
                .font(font)
                .multilineTextAlignment(textAlignment)
                .foregroundStyle(themeManager.accentColor)
        } else {
            // 未开始演唱：显示静止未激活状态，0 渐变开销
            Text(text)
                .font(font)
                .multilineTextAlignment(textAlignment)
                .foregroundStyle(isActive ? AnyShapeStyle(activeGradient) : AnyShapeStyle(inactiveColor))
        }
    }
}
