//
//  HeartbeatModeIcon.swift
//  glMusic
//
//  Created by go love on 11/15/26.
//

import SwiftUI

/// 网易云音乐经典“心动模式 / 智能漫游”闪电心形图标组件
/// - isActive = false: 空心心形 + 右上角微型闪电脉冲
/// - isActive = true: 实心心形 + 右上角闪电缺口
struct HeartbeatModeIcon: View {
    var isActive: Bool
    var size: CGFloat = 16

    var body: some View {
        Image(isActive ? "HeartbeatModeFill" : "HeartbeatMode")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size * (28.0 / 30.0))
    }
}
