import XCTest
import AppKit
@testable import glMusic

final class ArtworkColorExtractorTests: XCTestCase {

    func testDefaultPaletteIsVibrantAndNonBlack() {
        let palette = ArtworkColorExtractor.shared.extractPalette(from: nil, forSongId: 999999)

        XCTAssertEqual(palette.colors.count, 4)
        for color in palette.colors {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
            // 确保色彩明快，不是死黑或无特征极深色 (RGB 总和 > 0.6)
            XCTAssertGreaterThan(r + g + b, 0.6)
        }

        var baseR: CGFloat = 0, baseG: CGFloat = 0, baseB: CGFloat = 0, baseA: CGFloat = 0
        palette.baseBackground.usingColorSpace(.sRGB)?.getRed(&baseR, green: &baseG, blue: &baseB, alpha: &baseA)
        // 确保底色是深色但带有光感氛围，而非 RGB(0,0,0)
        XCTAssertGreaterThan(baseR + baseG + baseB, 0.15)
    }

    func testVibrantColorExtractionFromSynthesizedImage() {
        // 创建一个包含纯紫和天蓝对比色的合成测试图像
        let size = NSSize(width: 48, height: 48)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor(srgbRed: 0.85, green: 0.15, blue: 0.55, alpha: 1.0).setFill()
        NSRect(x: 0, y: 0, width: 24, height: 48).fill()
        NSColor(srgbRed: 0.15, green: 0.70, blue: 0.90, alpha: 1.0).setFill()
        NSRect(x: 24, y: 0, width: 24, height: 48).fill()
        img.unlockFocus()

        let palette = ArtworkColorExtractor.shared.extractPalette(from: img, forSongId: 888888)
        XCTAssertEqual(palette.colors.count, 4)

        // 验证主色经过 Apple Music 生动度映射后具有高饱和度与充足明度
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        palette.primary.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        XCTAssertGreaterThanOrEqual(s, 0.65)
        XCTAssertGreaterThanOrEqual(b, 0.50)
    }

    func testCacheHitForSameSongId() {
        let palette1 = ArtworkColorExtractor.shared.extractPalette(from: nil, forSongId: 777777)
        let palette2 = ArtworkColorExtractor.shared.extractPalette(from: nil, forSongId: 777777)
        XCTAssertEqual(palette1, palette2)
    }
}
