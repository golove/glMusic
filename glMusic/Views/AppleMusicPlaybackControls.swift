//
//  AppleMusicPlaybackControls.swift
//  glMusic
//
//  Created by go love on 11/14/26.
//

import SwiftUI

/// 播放控制按钮运动方向
enum PlaybackControlDirection {
    case forward   // 下一首：三箭头向右流动穿梭
    case backward  // 上一首：三箭头向左流动穿梭
    case center    // 播放/暂停/循环/随机：弹性形变与形态渐变
}

/// Apple Music 风格微拟物弹性按钮样式
/// - 鼠标按下时：产生物理按压微缩进（0.88x）与通透度变化
/// - 鼠标释放时：由 Apple 弹性弹簧物理引擎（response: 0.25, dampingFraction: 0.65）平滑回弹
struct AppleMusicPlaybackButtonStyle: ButtonStyle {
    var direction: PlaybackControlDirection = .center
    var scaleAmount: CGFloat = 0.88

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? 0.80 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

/// Apple Music 同款三箭头滑动穿梭流体动效
/// 完美复刻 Apple Music 点击下一首/上一首时的连续三角形传送带穿梭动效：
/// - 退出箭头 (Exiting)：向外滑动淡出并轻微缩小
/// - 推进箭头 (Advancing)：从后位平滑推进至前位
/// - 补位新箭头 (Entering)：从后方深处滑入并淡入放大补位
/// 数学上满足 C^0 全局连续性，连续快速点击无任何跳变与闪烁
struct AppleMusicChevronConveyorView: View, Animatable {
    var progress: CGFloat
    let isForward: Bool
    let size: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let d = size * 0.44
        let dir: CGFloat = isForward ? 1.0 : -1.0
        let triSize = size * 0.68
        let step = floor(progress)
        let localP = progress - step

        ZStack {
            // 退出箭头 (向外滑动淡出)
            Image(systemName: "play.fill")
                .font(.system(size: triSize))
                .rotationEffect(isForward ? .zero : .degrees(180))
                .scaleEffect(max(0.2, 1.0 - localP * 0.35))
                .opacity(max(0, 1.0 - Double(localP) * 1.3))
                .offset(x: (isForward ? (d * 0.5) : (-d * 0.5)) + dir * localP * d)

            // 推进箭头 (从后位推进至前位)
            Image(systemName: "play.fill")
                .font(.system(size: triSize))
                .rotationEffect(isForward ? .zero : .degrees(180))
                .offset(x: (isForward ? (-d * 0.5) : (d * 0.5)) + dir * localP * d)

            // 补位新箭头 (从后方深处渐入补位)
            Image(systemName: "play.fill")
                .font(.system(size: triSize))
                .rotationEffect(isForward ? .zero : .degrees(180))
                .scaleEffect(min(1.0, 0.65 + localP * 0.35))
                .opacity(min(1.0, max(0, Double(localP) * 1.3)))
                .offset(x: (isForward ? (-d * 1.5) : (d * 1.5)) + dir * localP * d)
        }
        .frame(width: size * 1.4, height: size)
    }
}

/// Apple Music 风格专属动效播放控制按钮
/// 1. 上一首/下一首：Apple Music 标志性三箭头滑动穿梭流体动效 (`AppleMusicChevronConveyorView`)
/// 2. 播放/暂停：SF Symbols 平滑形态演变替换 (`.contentTransition(.symbolEffect(.replace))`)
/// 3. 循环/随机：原生分层弹跳触感 (`.symbolEffect(.bounce)`)
struct AppleMusicPlaybackButton<S: ShapeStyle>: View {
    let systemName: String
    let fontSize: CGFloat
    var foregroundStyle: S
    var direction: PlaybackControlDirection = .center
    var isMorphing: Bool = false
    let action: () -> Void

    @State private var triggerCount: Int = 0
    @State private var conveyorProgress: CGFloat = 0
    @State private var isHovering: Bool = false

    init(
        systemName: String,
        fontSize: CGFloat,
        foregroundStyle: S = .primary,
        direction: PlaybackControlDirection = .center,
        isMorphing: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.fontSize = fontSize
        self.foregroundStyle = foregroundStyle
        self.direction = direction
        self.isMorphing = isMorphing
        self.action = action
    }

    var body: some View {
        Button {
            triggerAnimation()
            action()
        } label: {
            Group {
                if direction == .forward {
                    AppleMusicChevronConveyorView(
                        progress: conveyorProgress,
                        isForward: true,
                        size: fontSize
                    )
                } else if direction == .backward {
                    AppleMusicChevronConveyorView(
                        progress: conveyorProgress,
                        isForward: false,
                        size: fontSize
                    )
                } else if isMorphing {
                    Image(systemName: systemName)
                        .font(.system(size: fontSize))
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: triggerCount)
                } else {
                    Image(systemName: systemName)
                        .font(.system(size: fontSize))
                        .symbolEffect(.bounce, value: triggerCount)
                }
            }
            .foregroundStyle(foregroundStyle)
            .opacity(isHovering ? 1.0 : 0.90)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(AppleMusicPlaybackButtonStyle(direction: direction))
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func triggerAnimation() {
        triggerCount += 1

        if direction == .forward || direction == .backward {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) {
                conveyorProgress += 1.0
            }
        }
    }
}
