import Foundation
import Testing
@testable import GitMac

@Suite("Production layout uses visible points, not Retina pixels")
struct ResponsiveLayoutTests {
    @Test func compactPanelsCollapseAndRestoreOnlyAutomaticChoices() {
        typealias Panels = DesignTokens.Layout.Responsive.Panels
        let wide = Panels()
        let compact = wide.fitting(width: 640)
        #expect(!compact.sidebarVisible && !compact.inspectorVisible)
        #expect(compact.sidebarCollapsedForSpace && compact.inspectorCollapsedForSpace)
        #expect(compact.fitting(width: 1280) == wide)
        let medium = wide.fitting(width: 900)
        #expect(medium.sidebarVisible && !medium.inspectorVisible)
        #expect(!medium.sidebarCollapsedForSpace && medium.inspectorCollapsedForSpace)
        #expect(medium.fitting(width: 1280) == wide)

        let manual = Panels(sidebarVisible: false, inspectorVisible: false)
        #expect(manual.fitting(width: 640).fitting(width: 1280) == manual)
        #expect(wide.fitting(width: .nan) == wide)
        #expect(wide.fitting(width: 0) == wide)
    }

    @Test(arguments: [CGSize(width: 640, height: 480), CGSize(width: 1280, height: 800),
                      CGSize(width: 1512, height: 950), CGSize(width: 2560, height: 1409)])
    func oversizedWindowFitsUsableScreen(_ size: CGSize) {
        for origin in [CGPoint.zero, CGPoint(x: -1920, y: 40), CGPoint(x: 2560, y: -100)] {
            let visible = CGRect(origin: origin, size: size)
            let oversized = CGRect(x: origin.x - 300, y: origin.y - 600, width: 3840, height: 2160)
            let fitted = DesignTokens.Layout.Responsive.windowFrame(oversized, fitting: visible)
            #expect(visible.contains(fitted))
            #expect(fitted.width <= size.width && fitted.height <= size.height)
            #expect(DesignTokens.Layout.Responsive.windowFrame(fitted, fitting: visible) == fitted)
        }
    }

    @Test func validUserWindowPositionAndPointSizeRemainUnchanged() {
        let visible = CGRect(x: 2560, y: 0, width: 1512, height: 950)
        let userFrame = CGRect(x: 2700.5, y: 100.5, width: 900.5, height: 700.5)
        #expect(DesignTokens.Layout.Responsive.windowFrame(userFrame, fitting: visible) == userFrame)
    }

    @Test func retinaPixelDimensionsAreNotUsedAsLogicalWindowSize() {
        let visiblePoints = CGRect(x: 0, y: 0, width: 1512, height: 950)
        for backingScale in [CGFloat(1), CGFloat(2)] {
            let restoredPixelSizedFrame = CGRect(x: 300, y: 249, width: 1512 * backingScale, height: 982 * backingScale)
            let fitted = DesignTokens.Layout.Responsive.windowFrame(restoredPixelSizedFrame, fitting: visiblePoints)
            #expect(visiblePoints.contains(fitted))
            #expect(fitted.width == 1512 && fitted.height == 950)
        }
    }

    @Test func disconnectedMonitorFrameIsMovedIntoCurrentScreen() {
        let visible = CGRect(x: 0, y: 0, width: 1512, height: 950)
        let old = CGRect(x: 2900, y: -700, width: 1105, height: 791)
        let fitted = DesignTokens.Layout.Responsive.windowFrame(old, fitting: visible)
        #expect(visible.contains(fitted))
        #expect(fitted.size == old.size)
    }

    @Test(arguments: [CGFloat(0), 200, 380, 480, 800, 950, 1409])
    func terminalCannotConsumeTheEntireWindow(_ available: CGFloat) {
        let limit = DesignTokens.Layout.Responsive.bottomPanelLimit(availableHeight: available)
        #expect(limit.isFinite && limit >= 0 && limit <= available)
        if available >= 180 { #expect(available - limit >= 180) }
        for preference in [CGFloat(-100), 100, 300, 600, 10000, .nan, .infinity] {
            let height = DesignTokens.Layout.Responsive.bottomPanelHeight(preferred: preference, maximum: limit)
            #expect(height.isFinite && height >= 0 && height <= limit)
        }
    }

    @Test func invalidStoredWindowDimensionsHaveFiniteFallback() {
        let visible = CGRect(x: 0, y: 0, width: 1280, height: 800)
        let invalid = CGRect(x: CGFloat.nan, y: CGFloat.infinity, width: CGFloat.nan, height: CGFloat.infinity)
        let fitted = DesignTokens.Layout.Responsive.windowFrame(invalid, fitting: visible)
        #expect(visible.contains(fitted))
        #expect(fitted.width.isFinite && fitted.height.isFinite)
    }
}
