//
//  LanguageManager.swift
//  glMusic
//
//  Created by go love on 11/6/26.
//

import SwiftUI
import Foundation

/// 界面支持的显示语言
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case zhHans = "zh-Hans"
    case en = "en"
    case zhHant = "zh-Hant"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return LanguageManager.shared.localized("跟随系统")
        case .zhHans:
            return "简体中文"
        case .en:
            return "English"
        case .zhHant:
            return "繁體中文"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .system:
            return LanguageManager.shared.localized("系统")
        case .zhHans:
            return "简中"
        case .en:
            return "EN"
        case .zhHant:
            return "繁中"
        }
    }

    var nativeName: String {
        switch self {
        case .system:
            return "System"
        case .zhHans:
            return "简体中文"
        case .en:
            return "English"
        case .zhHant:
            return "繁體中文"
        }
    }

    /// 对应的本地化资源目录代号
    var localizationIdentifier: String {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "zh-Hans"
            if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-HK") || preferred.hasPrefix("zh-TW") {
                return "zh-Hant"
            } else if preferred.hasPrefix("zh") {
                return "zh-Hans"
            } else {
                return "en"
            }
        case .zhHans:
            return "zh-Hans"
        case .en:
            return "en"
        case .zhHant:
            return "zh-Hant"
        }
    }

    var locale: Locale {
        Locale(identifier: localizationIdentifier)
    }
}

@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            if currentLanguage == .system {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.set([currentLanguage.localizationIdentifier], forKey: "AppleLanguages")
            }
            updateBundle()
        }
    }

    private(set) var currentLocale: Locale
    private(set) var bundle: Bundle = .main

    private init() {
        let saved = UserDefaults.standard.string(forKey: "app_language") ?? AppLanguage.system.rawValue
        let lang = AppLanguage(rawValue: saved) ?? .system
        self.currentLanguage = lang
        self.currentLocale = lang.locale
        updateBundle()
    }

    func select(_ language: AppLanguage) {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentLanguage = language
        }
    }

    private func updateBundle() {
        currentLocale = currentLanguage.locale
        let id = currentLanguage.localizationIdentifier
        if let path = Bundle.main.path(forResource: id, ofType: "lproj"),
           let subBundle = Bundle(path: path) {
            self.bundle = subBundle
        } else {
            self.bundle = .main
        }
    }

    /// 多语言检索核心方法
    func localized(_ key: String, defaultValue: String? = nil) -> String {
        let result = bundle.localizedString(forKey: key, value: defaultValue, table: nil)
        if result == key, let defaultValue = defaultValue {
            return defaultValue
        }
        return result
    }
}

extension String {
    /// 快速多语言提取
    var localized: String {
        LanguageManager.shared.localized(self)
    }

    /// 支持带格式化参数的多语言
    func localized(with arguments: CVarArg...) -> String {
        let format = LanguageManager.shared.localized(self)
        return String(format: format, locale: LanguageManager.shared.currentLocale, arguments: arguments)
    }
}
