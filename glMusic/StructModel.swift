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
        .init(id: "home",           name: "现在就听", systemImage: "play.circle.fill",              children: nil),
        .init(id: "personalFm",     name: "私人 FM",  systemImage: "dot.radiowaves.left.and.right", children: nil),
        .init(id: "daily",          name: "每日推荐", systemImage: "calendar.badge.clock",          children: nil),
        .init(id: "playlistSquare", name: "歌单广场", systemImage: "square.grid.2x2",               children: nil),
        .init(id: "browse",         name: "浏览",     systemImage: "safari",                        children: nil),
        .init(id: "radio",          name: "广播",     systemImage: "dot.radiowaves.left.and.right",  children: nil),
        .init(id: "search",         name: "搜索",     systemImage: "magnifyingglass",                children: nil),
        .init(id: "library", name: "资料库", systemImage: nil, children: [
            .init(id: "history",    name: "播放历史", systemImage: "clock.arrow.circlepath", children: nil),
            .init(id: "artists",    name: "艺人",     systemImage: "music.mic",              children: nil),
            .init(id: "albums",     name: "专辑",     systemImage: "square.stack",            children: nil),
            .init(id: "songs",      name: "歌曲",     systemImage: "music.note",             children: nil),
            .init(id: "downloaded", name: "本地与下载", systemImage: "arrow.down.circle.fill", children: nil),
        ]),
    ]
}

// MARK: - Zero-Allocation RandomAccess Indexed Collection
// 零堆内存分配的轻量索引虚拟集合：消除 ForEach(Array(collection.enumerated())) 造成的频繁堆数组分配与 GC 压力

struct IndexedCollection<Base: RandomAccessCollection>: RandomAccessCollection {
    typealias Index = Base.Index
    typealias Element = IndexedElement<Base.Element>

    let base: Base

    var startIndex: Index { base.startIndex }
    var endIndex: Index { base.endIndex }

    func index(after i: Index) -> Index { base.index(after: i) }
    func index(before i: Index) -> Index { base.index(before: i) }

    subscript(position: Index) -> Element {
        let offset = base.distance(from: base.startIndex, to: position)
        return IndexedElement(index: offset, element: base[position])
    }
}

struct IndexedElement<Element> {
    let index: Int
    let element: Element
}

extension IndexedElement: Identifiable where Element: Identifiable {
    var id: Element.ID { element.id }
}

extension RandomAccessCollection {
    func indexed() -> IndexedCollection<Self> {
        IndexedCollection(base: self)
    }
}
