//
//  ThemeManager.swift
//  glMusic
//
//  Created by go love on 11/3/26.
//

import SwiftUI

/// 清新配色主题定义
enum AppTheme: String, CaseIterable, Identifiable {
    case sakura = "樱花柔粉"
    case mint = "薄荷清风"
    case ocean = "海风清蓝"
    case matcha = "抹茶初夏"
    case peach = "蜜桃日落"
    case lavender = "薰衣草紫"

    var id: String { rawValue }

    var localizedName: String {
        rawValue.localized
    }

    var englishName: String {
        switch self {
        case .sakura:   return "Sakura Pink"
        case .mint:     return "Mint Breeze"
        case .ocean:    return "Sea Breeze"
        case .matcha:   return "Matcha Green"
        case .peach:    return "Peach Sunset"
        case .lavender: return "Lavender Mist"
        }
    }

    var description: String {
        switch self {
        case .sakura:   return "温柔轻盈 · Apple Music 经典粉质感升华"
        case .mint:     return "通透清凉 · 类似夏日气泡苏打的沉浸感"
        case .ocean:    return "晴空蔚蓝 · 地中海海风与广袤天际"
        case .matcha:   return "自然茶香 · 森林系自然治愈与护眼"
        case .peach:    return "元气甜橙 · 黄昏落日微光与温暖明朗"
        case .lavender: return "梦幻罗兰 · 雅致轻奢、夜间听歌极佳"
        }
    }

    /// 主强调色 (Primary Accent)
    var primaryColor: Color {
        switch self {
        case .sakura:   return Color(red: 0.96, green: 0.25, blue: 0.37) // #F43F5E
        case .mint:     return Color(red: 0.06, green: 0.73, blue: 0.51) // #10B981
        case .ocean:    return Color(red: 0.05, green: 0.65, blue: 0.91) // #0EA5E9
        case .matcha:   return Color(red: 0.09, green: 0.64, blue: 0.29) // #16A34A
        case .peach:    return Color(red: 0.98, green: 0.45, blue: 0.09) // #F97316
        case .lavender: return Color(red: 0.55, green: 0.36, blue: 0.96) // #8B5CF6
        }
    }

    /// 胶囊浅色底色 (Tint Background, ~12% opacity)
    var tintColor: Color {
        primaryColor.opacity(0.12)
    }

    /// 渐变色对 (用于横幅、日历卡片等重点视觉区域)
    var gradientColors: [Color] {
        switch self {
        case .sakura:
            return [Color(red: 0.96, green: 0.25, blue: 0.37), Color(red: 0.99, green: 0.45, blue: 0.55)]
        case .mint:
            return [Color(red: 0.06, green: 0.73, blue: 0.51), Color(red: 0.02, green: 0.71, blue: 0.83)]
        case .ocean:
            return [Color(red: 0.05, green: 0.65, blue: 0.91), Color(red: 0.23, green: 0.51, blue: 0.96)]
        case .matcha:
            return [Color(red: 0.09, green: 0.64, blue: 0.29), Color(red: 0.52, green: 0.80, blue: 0.09)]
        case .peach:
            return [Color(red: 0.98, green: 0.45, blue: 0.09), Color(red: 0.99, green: 0.58, blue: 0.25)]
        case .lavender:
            return [Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.68, green: 0.38, blue: 0.98)]
        }
    }

    /// 渐变伴生次色 (用于多重光斑丰富层次)
    var secondaryColor: Color {
        gradientColors.last ?? primaryColor
    }

    /// 夜景光斑晶莹高光色 (类似路灯与车灯的晶莹高光反光)
    var highlightColor: Color {
        switch self {
        case .sakura:   return Color(red: 1.0, green: 0.88, blue: 0.92) // 晶亮浅樱粉
        case .mint:     return Color(red: 0.70, green: 1.0, blue: 0.92) // 晶亮青柠水绿
        case .ocean:    return Color(red: 0.76, green: 0.94, blue: 1.0) // 冰晶透蓝
        case .matcha:   return Color(red: 0.92, green: 0.98, blue: 0.72) // 晨露嫩黄
        case .peach:    return Color(red: 1.0, green: 0.92, blue: 0.78) // 暮色暖金
        case .lavender: return Color(red: 0.93, green: 0.86, blue: 1.0) // 柔光丁香白
        }
    }

    /// 歌词高光柔和渐变色对 (淡化约 60%，融入通透亮白，呈现清澈柔和的高级感)
    var lyricSoftColors: (primary: Color, secondary: Color) {
        switch self {
        case .sakura:
            return (
                Color(red: 0.98, green: 0.70, blue: 0.75),
                Color(red: 0.99, green: 0.78, blue: 0.82)
            )
        case .mint:
            return (
                Color(red: 0.62, green: 0.89, blue: 0.80),
                Color(red: 0.61, green: 0.88, blue: 0.93)
            )
        case .ocean:
            return (
                Color(red: 0.62, green: 0.86, blue: 0.96),
                Color(red: 0.69, green: 0.80, blue: 0.98)
            )
        case .matcha:
            return (
                Color(red: 0.64, green: 0.86, blue: 0.72),
                Color(red: 0.81, green: 0.92, blue: 0.64)
            )
        case .peach:
            return (
                Color(red: 0.99, green: 0.78, blue: 0.64),
                Color(red: 0.99, green: 0.83, blue: 0.70)
            )
        case .lavender:
            return (
                Color(red: 0.82, green: 0.74, blue: 0.98),
                Color(red: 0.87, green: 0.75, blue: 0.99)
            )
        }
    }

    var systemIcon: String {
        switch self {
        case .sakura:   return "heart.fill"
        case .mint:     return "leaf.fill"
        case .ocean:    return "water.waves"
        case .matcha:   return "camera.macro"
        case .peach:    return "sun.max.fill"
        case .lavender: return "sparkles"
        }
    }

    var hexString: String {
        switch self {
        case .sakura:   return "#F43F5E"
        case .mint:     return "#10B981"
        case .ocean:    return "#0EA5E9"
        case .matcha:   return "#16A34A"
        case .peach:    return "#F97316"
        case .lavender: return "#8B5CF6"
        }
    }
}

/// 主题状态管理器
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "glMusic_app_theme")
        }
    }

    var accentColor: Color {
        currentTheme.primaryColor
    }

    var tintColor: Color {
        currentTheme.tintColor
    }

    var gradient: [Color] {
        currentTheme.gradientColors
    }

    var secondaryColor: Color {
        currentTheme.secondaryColor
    }

    var highlightColor: Color {
        currentTheme.highlightColor
    }

    /// 歌词高光柔和渐变色对 (淡化约 60%)
    var lyricSoftColors: (primary: Color, secondary: Color) {
        currentTheme.lyricSoftColors
    }

    /// 歌词高光柔和渐变 (顶部高光亮白过渡到淡化约 60% 的主题淡彩色，极高通透感与辨识度)
    var lyricSoftGradient: LinearGradient {
        let softColors = currentTheme.lyricSoftColors
        return LinearGradient(
            stops: [
                .init(color: .white, location: 0.0),
                .init(color: .white.opacity(0.96), location: 0.35),
                .init(color: softColors.primary, location: 0.75),
                .init(color: softColors.secondary, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "glMusic_app_theme") ?? ""
        self.currentTheme = AppTheme(rawValue: saved) ?? .sakura
    }

    func select(_ theme: AppTheme) {
        withAnimation(.easeInOut(duration: 0.22)) {
            currentTheme = theme
        }
    }
}
