//
//  ArtistClickableLabel.swift
//  glMusic
//
//  Created by go love on 11/4/26.
//

import SwiftUI
import AppKit

/// Apple Music 风格可交互歌手/专辑链接标签，支持悬停高亮、下划线及系统指针光标切换
struct ArtistClickableLabel: View {
    let name: String
    var fontSize: CGFloat = 11
    var weight: Font.Weight = .regular
    var normalColor: Color = .secondary
    var hoverColor: Color = .primary
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: {
            resetCursor()
            action()
        }) {
            Text(name)
                .font(.system(size: fontSize, weight: weight))
                .foregroundStyle(isHovered ? hoverColor : normalColor)
                .underline(isHovered)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .onHover { hov in
            guard isHovered != hov else { return }
            isHovered = hov
            if hov {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onDisappear {
            resetCursor()
        }
    }

    private func resetCursor() {
        if isHovered {
            NSCursor.pop()
            isHovered = false
        }
    }
}

/// 支持多歌手以 " / " 分隔并各自支持点击跳转的组合视图
struct ArtistLinksView: View {
    let artists: [APIArtistBrief]?
    let fallbackText: String
    var fontSize: CGFloat = 11
    var weight: Font.Weight = .regular
    var normalColor: Color = .secondary
    var hoverColor: Color = .primary
    var separatorColor: Color? = nil
    let onSelectArtist: (Int) -> Void

    var body: some View {
        let validArtists = (artists ?? []).filter { !($0.name ?? "").trimmingCharacters(in: .whitespaces).isEmpty }

        if validArtists.isEmpty {
            Text(fallbackText.isEmpty ? "未知艺人" : fallbackText)
                .font(.system(size: fontSize, weight: weight))
                .foregroundStyle(normalColor)
                .lineLimit(1)
        } else {
            HStack(spacing: 0) {
                ForEach(Array(validArtists.enumerated()), id: \.offset) { index, artist in
                    if index > 0 {
                        Text(" / ")
                            .font(.system(size: fontSize, weight: weight))
                            .foregroundStyle(separatorColor ?? normalColor)
                    }
                    if let id = artist.id, id > 0 {
                        ArtistClickableLabel(
                            name: artist.name ?? "",
                            fontSize: fontSize,
                            weight: weight,
                            normalColor: normalColor,
                            hoverColor: hoverColor
                        ) {
                            onSelectArtist(id)
                        }
                    } else {
                        Text(artist.name ?? "")
                            .font(.system(size: fontSize, weight: weight))
                            .foregroundStyle(normalColor)
                    }
                }
            }
            .lineLimit(1)
            .truncationMode(.tail)
        }
    }
}
