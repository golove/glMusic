//
//  NightBokehBackground.swift
//  glMusic
//
//  Created by go love on 11/4/26.
//

import SwiftUI

/// 光斑光学形态风格
enum BokehStyle {
    case diffuseCloud    // 远景柔和弥散光晕 (大面积夜景色调)
    case softOrb         // 经典焦外柔光球 (中景柔和光晕)
    case crispDisc       // 具象清晰光斑 (边缘清晰分明，带微亮光圈边缘，还原大光圈摄影光斑)
    case sparklingPin    // 晶莹微光点 (近景高亮锐利光点)
}

/// 拟真城市夜景镜头光斑 (Bokeh Light Spot)
struct BokehSpot: Identifiable {
    let id: Int
    /// 相对坐标 (0.0 ~ 1.0)
    let xRatio: CGFloat
    let yRatio: CGFloat
    /// 光斑基准直径
    let diameter: CGFloat
    /// 虚化模糊半径 (crispDisc 采用 1.5~2.5)
    let blurRadius: CGFloat
    /// 核心不透明度
    let baseOpacity: Double
    /// 色彩类型: 0 = 主题主色, 1 = 渐变伴生次色, 2 = 晶莹反光高光色
    let colorType: Int
    /// 光学形态风格
    let style: BokehStyle
    /// 浮动偏移量 (X, Y)
    let driftRange: CGSize
}

/// 城市夜景灯光流光氛围背景 (Night City Bokeh Ambient Background)
struct NightBokehBackground: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var isBreathing = false

    /// 19 个精心布局的夜景散景光斑（远景柔光、中景柔球、具象清晰光圈、近景晶莹亮点）
    private let spots: [BokehSpot] = [
        // MARK: - 1. 远景大光晕 (构建夜景基底氛围色调)
        BokehSpot(id: 1,  xRatio: 0.82, yRatio: 0.15, diameter: 290, blurRadius: 50, baseOpacity: 0.12, colorType: 0, style: .diffuseCloud, driftRange: CGSize(width: 14, height: -12)),
        BokehSpot(id: 2,  xRatio: 0.15, yRatio: 0.20, diameter: 230, blurRadius: 44, baseOpacity: 0.10, colorType: 1, style: .diffuseCloud, driftRange: CGSize(width: -10, height: 12)),
        BokehSpot(id: 3,  xRatio: 0.50, yRatio: 0.70, diameter: 260, blurRadius: 52, baseOpacity: 0.09, colorType: 0, style: .diffuseCloud, driftRange: CGSize(width: 12, height: 14)),
        BokehSpot(id: 4,  xRatio: 0.88, yRatio: 0.82, diameter: 250, blurRadius: 46, baseOpacity: 0.11, colorType: 1, style: .diffuseCloud, driftRange: CGSize(width: -12, height: -10)),

        // MARK: - 2. 中景经典焦外柔光球 (柔和景深)
        BokehSpot(id: 5,  xRatio: 0.70, yRatio: 0.28, diameter: 130, blurRadius: 22, baseOpacity: 0.15, colorType: 1, style: .softOrb, driftRange: CGSize(width: -14, height: 10)),
        BokehSpot(id: 6,  xRatio: 0.08, yRatio: 0.48, diameter: 110, blurRadius: 18, baseOpacity: 0.14, colorType: 0, style: .softOrb, driftRange: CGSize(width: 12, height: -8)),
        BokehSpot(id: 7,  xRatio: 0.32, yRatio: 0.62, diameter: 120, blurRadius: 20, baseOpacity: 0.13, colorType: 1, style: .softOrb, driftRange: CGSize(width: -10, height: 12)),
        BokehSpot(id: 8,  xRatio: 0.78, yRatio: 0.75, diameter: 135, blurRadius: 22, baseOpacity: 0.14, colorType: 0, style: .softOrb, driftRange: CGSize(width: 12, height: -12)),

        // MARK: - 3. 具象清晰光斑 (稍微没那么虚、轮廓清晰、带微亮边缘光圈的大光圈散景)
        BokehSpot(id: 9,  xRatio: 0.78, yRatio: 0.18, diameter: 74,  blurRadius: 2.0, baseOpacity: 0.17, colorType: 0, style: .crispDisc, driftRange: CGSize(width: -10, height: 8)),
        BokehSpot(id: 10, xRatio: 0.86, yRatio: 0.32, diameter: 54,  blurRadius: 1.5, baseOpacity: 0.21, colorType: 1, style: .crispDisc, driftRange: CGSize(width: 8, height: -10)),
        BokehSpot(id: 11, xRatio: 0.68, yRatio: 0.40, diameter: 88,  blurRadius: 2.2, baseOpacity: 0.15, colorType: 2, style: .crispDisc, driftRange: CGSize(width: -8, height: -8)),
        BokehSpot(id: 12, xRatio: 0.18, yRatio: 0.35, diameter: 62,  blurRadius: 1.8, baseOpacity: 0.18, colorType: 0, style: .crispDisc, driftRange: CGSize(width: 10, height: 8)),
        BokehSpot(id: 13, xRatio: 0.25, yRatio: 0.72, diameter: 68,  blurRadius: 2.0, baseOpacity: 0.16, colorType: 2, style: .crispDisc, driftRange: CGSize(width: -8, height: 10)),
        BokehSpot(id: 14, xRatio: 0.62, yRatio: 0.82, diameter: 80,  blurRadius: 2.2, baseOpacity: 0.15, colorType: 1, style: .crispDisc, driftRange: CGSize(width: 8, height: -10)),
        BokehSpot(id: 15, xRatio: 0.92, yRatio: 0.58, diameter: 48,  blurRadius: 1.5, baseOpacity: 0.22, colorType: 0, style: .crispDisc, driftRange: CGSize(width: -6, height: 6)),

        // MARK: - 4. 近景晶莹微光点 (锐利微星芒、车灯反光)
        BokehSpot(id: 16, xRatio: 0.94, yRatio: 0.18, diameter: 30,  blurRadius: 2.5, baseOpacity: 0.34, colorType: 2, style: .crispDisc, driftRange: CGSize(width: 6, height: -6)),
        BokehSpot(id: 17, xRatio: 0.64, yRatio: 0.20, diameter: 36,  blurRadius: 3.0, baseOpacity: 0.30, colorType: 2, style: .softOrb, driftRange: CGSize(width: -8, height: 8)),
        BokehSpot(id: 18, xRatio: 0.20, yRatio: 0.82, diameter: 26,  blurRadius: 2.0, baseOpacity: 0.36, colorType: 2, style: .crispDisc, driftRange: CGSize(width: 6, height: 8)),
        BokehSpot(id: 19, xRatio: 0.45, yRatio: 0.88, diameter: 34,  blurRadius: 2.8, baseOpacity: 0.28, colorType: 0, style: .softOrb, driftRange: CGSize(width: -6, height: -8)),
    ]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                // 1. 底层极弱底色，沉淀整体冷暖氛围
                themeManager.accentColor.opacity(0.04)

                // 2. 顶部微光弥散渐变
                LinearGradient(
                    colors: [
                        themeManager.accentColor.opacity(0.08),
                        themeManager.secondaryColor.opacity(0.04),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )

                // 3. 散落的夜景多重散景光斑（虚实交错）
                ForEach(spots) { spot in
                    let color = colorFor(type: spot.colorType)
                    let centerPos = CGPoint(x: width * spot.xRatio, y: height * spot.yRatio)
                    let currentOffset = isBreathing ? spot.driftRange : CGSize(
                        width: -spot.driftRange.width * 0.7,
                        height: -spot.driftRange.height * 0.7
                    )
                    let scale = isBreathing ? 1.05 : 0.95

                    renderSpotView(spot: spot, color: color)
                        .scaleEffect(scale)
                        .position(centerPos)
                        .offset(currentOffset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.35), value: themeManager.currentTheme)
        .onAppear {
            // 延迟启动呼吸动画，避免与页面入场 transition 竞争导致卡顿
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeInOut(duration: 6.5).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }
        }
    }

    // MARK: - Spot View Renderer

    @ViewBuilder
    private func renderSpotView(spot: BokehSpot, color: Color) -> some View {
        switch spot.style {
        case .diffuseCloud, .softOrb:
            // 柔和弥散光晕
            RadialGradient(
                colors: [
                    color.opacity(spot.baseOpacity),
                    color.opacity(spot.baseOpacity * 0.65),
                    color.opacity(spot.baseOpacity * 0.15),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: spot.diameter / 2
            )
            .frame(width: spot.diameter, height: spot.diameter)
            .blur(radius: spot.blurRadius)

        case .crispDisc:
            // 具象清晰光斑：圆盘形状清晰可见，边缘微亮（还原真实大光圈镜头边缘光圈环特征）
            ZStack {
                // 内部半透光盘
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                color.opacity(spot.baseOpacity * 0.50),
                                color.opacity(spot.baseOpacity * 0.70),
                                color.opacity(spot.baseOpacity * 0.90)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: spot.diameter / 2
                        )
                    )

                // 清晰镜头光圈边缘轮廓圈
                Circle()
                    .strokeBorder(color.opacity(spot.baseOpacity * 1.55), lineWidth: 1.2)
            }
            .frame(width: spot.diameter, height: spot.diameter)
            .blur(radius: spot.blurRadius) // 仅 1.5 ~ 2.2px 轻微虚化消除锯齿，圆形轮廓清晰分明

        case .sparklingPin:
            // 晶莹微光点：高亮核心
            ZStack {
                Circle()
                    .fill(color.opacity(spot.baseOpacity))
                    .frame(width: spot.diameter, height: spot.diameter)
                    .blur(radius: spot.blurRadius)

                Circle()
                    .fill(Color.white.opacity(spot.baseOpacity * 0.85))
                    .frame(width: spot.diameter * 0.38, height: spot.diameter * 0.38)
                    .blur(radius: 1.0)
            }
        }
    }

    private func colorFor(type: Int) -> Color {
        switch type {
        case 0:
            return themeManager.accentColor
        case 1:
            return themeManager.secondaryColor
        case 2:
            return themeManager.highlightColor
        default:
            return themeManager.accentColor
        }
    }
}

#Preview {
    ZStack {
        Color.black
        NightBokehBackground()
    }
    .frame(width: 800, height: 600)
    .environment(ThemeManager.shared)
}
