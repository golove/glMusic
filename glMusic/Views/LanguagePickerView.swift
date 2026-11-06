//
//  LanguagePickerView.swift
//  glMusic
//
//  Created by go love on 11/6/26.
//

import SwiftUI

/// 语言切换弹窗视图
struct LanguagePickerView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var languageManager
    var onSelect: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .foregroundStyle(themeManager.accentColor)
                    .font(.system(size: 15))
                Text("界面语言".localized)
                    .font(.headline)
                Spacer()
                Text(languageManager.currentLanguage.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("选择界面显示语言，即时生效".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            VStack(spacing: 6) {
                ForEach(AppLanguage.allCases) { lang in
                    let isSelected = languageManager.currentLanguage == lang
                    Button {
                        languageManager.select(lang)
                        onSelect?()
                    } label: {
                        HStack(spacing: 12) {
                            Text(flagOrIcon(for: lang))
                                .font(.system(size: 16))
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang.displayName)
                                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                    .foregroundStyle(isSelected ? themeManager.accentColor : .primary)
                                if lang != .system {
                                    Text(lang.nativeName)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(themeManager.accentColor)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? themeManager.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? themeManager.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private func flagOrIcon(for lang: AppLanguage) -> String {
        switch lang {
        case .system: return "🌐"
        case .zhHans: return "🇨🇳"
        case .en:     return "🇺🇸"
        case .zhHant: return "🇭🇰"
        }
    }
}

/// 放置在侧边栏底部的快捷语言切换按钮
struct LanguagePickerButton: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var languageManager
    @State private var showPopover = false
    @State private var isHovered = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "globe")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(languageManager.currentLanguage.shortDisplayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(isHovered ? 0.12 : 0.04), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("切换语言（当前: %@）".localized(with: languageManager.currentLanguage.displayName))
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            LanguagePickerView {
                showPopover = false
            }
        }
    }
}

#Preview {
    LanguagePickerView()
        .environment(ThemeManager.shared)
        .environment(LanguageManager.shared)
}
