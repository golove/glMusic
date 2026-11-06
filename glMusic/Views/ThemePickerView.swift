//
//  ThemePickerView.swift
//  glMusic
//
//  Created by go love on 11/3/26.
//

import SwiftUI

/// 清新主题切换卡片与选择器组件
struct ThemePickerView: View {
    @Environment(ThemeManager.self) private var themeManager
    var onSelect: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "paintpalette.fill")
                    .foregroundStyle(themeManager.accentColor)
                    .font(.system(size: 15))
                Text("个性化主题".localized)
                    .font(.headline)
                Spacer()
                Text(themeManager.currentTheme.localizedName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("为应用选择一套你喜欢的清新色调，实时同步至全站操作、指示器与动效".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // 6 款清新主题网格
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    let isSelected = themeManager.currentTheme == theme
                    Button {
                        themeManager.select(theme)
                        onSelect?()
                    } label: {
                        HStack(spacing: 10) {
                            // 色彩圆环
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: theme.gradientColors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 26, height: 26)

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .shadow(color: theme.primaryColor.opacity(0.3), radius: 4, y: 2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(theme.localizedName)
                                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                    .foregroundStyle(isSelected ? theme.primaryColor : .primary)
                                Text(theme.englishName)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? theme.primaryColor.opacity(0.12) : Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? theme.primaryColor : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}

/// 放置在侧边栏底部的快捷主题切换按钮
struct ThemePickerButton: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var showPopover = false
    @State private var isHovered = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: themeManager.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 9, height: 9)
                Text(themeManager.currentTheme.localizedName)
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
        .help("切换清新主题（当前: %@）".localized(with: themeManager.currentTheme.localizedName))
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            ThemePickerView {
                showPopover = false
            }
        }
    }
}

#Preview {
    ThemePickerView()
        .environment(ThemeManager.shared)
}
