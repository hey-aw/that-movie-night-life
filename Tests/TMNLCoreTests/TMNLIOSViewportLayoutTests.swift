import Testing
@testable import TMNLCore

struct TMNLIOSViewportLayoutTests {
    @Test
    func compactViewportUsesTwoMetricColumnsAndVerticalControls() {
        let layout = TMNLIOSViewportLayout(viewportWidth: 320)

        #expect(layout.isCompact)
        #expect(layout.metricsColumnCount == 2)
        #expect(layout.stacksControlsVertically)
        #expect(layout.stacksResultVertically)
        #expect(layout.reelDigitWidth == 46)
    }

    @Test
    func regularViewportKeepsHorizontalComposition() {
        let layout = TMNLIOSViewportLayout(viewportWidth: 600)

        #expect(!layout.isCompact)
        #expect(layout.metricsColumnCount == 4)
        #expect(!layout.stacksControlsVertically)
        #expect(!layout.stacksResultVertically)
        #expect(layout.posterWidth == 140)
    }
}
