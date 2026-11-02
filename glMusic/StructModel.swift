//
//  StructModel.swift
//  glMusic
//
//  Created by go love on 10/5/26.
//

import SwiftUI

// MARK: - Sidebar Model

struct SideBarItem: Identifiable, Hashable {
    let id: String
    let name: String
    let systemImage: String?
    let children: [SideBarItem]?

    var isSection: Bool { children != nil }
}

enum SideBar {
    static let items: [SideBarItem] = [
        .init(id: "home",   name: "现在就听", systemImage: "play.circle.fill",              children: nil),
        .init(id: "daily",  name: "每日推荐", systemImage: "calendar.badge.clock",          children: nil),
        .init(id: "browse", name: "浏览",     systemImage: "square.grid.2x2",               children: nil),
        .init(id: "radio",  name: "广播",     systemImage: "dot.radiowaves.left.and.right",  children: nil),
        .init(id: "search", name: "搜索",     systemImage: "magnifyingglass",                children: nil),
        .init(id: "library", name: "资料库", systemImage: nil, children: [
            .init(id: "recent",     name: "最近添加", systemImage: "clock",                  children: nil),
            .init(id: "artists",    name: "艺人",     systemImage: "music.mic",              children: nil),
            .init(id: "albums",     name: "专辑",     systemImage: "square.stack",            children: nil),
            .init(id: "songs",      name: "歌曲",     systemImage: "music.note",             children: nil),
            .init(id: "downloaded", name: "已下载",   systemImage: "arrow.down.circle.fill", children: nil),
        ]),
    ]
}
