import SwiftUI
import XCTest
@testable import kanji_test

@MainActor
final class FuriganaRenderingTests: XCTestCase {
    private let text = "学校は好き？"
    private var data: ExampleFurigana {
        ExampleFurigana(transcriptions: [TatoebaTranscription(text: "[学校|がっ|こう]は[好|す]き？", script: "Hrkt", type: "altscript")], checkedAt: Date())
    }

    func testShortSentenceReservesReadingWidth() {
        let view = drawingView(text: text, data: data)
        let layout = view.layout(width: 240)
        XCTAssertFalse(layout.placements.isEmpty)
        XCTAssertEqual(Set(layout.placements.map { $0.origin.y }).count, 1)
        assertNoOverlaps(layout, width: 240)
        attach(view, width: 240, name: "Short sentence")
    }

    func testLongSentenceWrapsAndFitsAtLargeDynamicTypeSizes() {
        let original = String(repeating: "学校は好き？", count: 20)
        let markup = String(repeating: "[学校|がっ|こう]は[好|す]き？", count: 20)
        let furigana = ExampleFurigana(transcriptions: [TatoebaTranscription(text: markup, script: "Hrkt", type: "altscript")], checkedAt: Date())
        for fontSize: CGFloat in [17, 34, 53] {
            let view = drawingView(text: original, data: furigana, fontSize: fontSize)
            let layout = view.layout(width: 240)
            XCTAssertGreaterThan(Set(layout.placements.map { $0.origin.y }).count, 1)
            assertNoOverlaps(layout, width: 240)
            XCTAssertEqual(view.accessibilityLabel, original)
            attach(view, width: 240, name: "Long sentence at \(fontSize)pt")
        }
    }

    func testVeryLongGroupReadingFitsNarrowContainer() {
        let data = ExampleFurigana(transcriptions: [TatoebaTranscription(text: "[国際連合教育科学文化機関|こくさいれんごうきょういくかがくぶんかきかん]", script: "Hrkt", type: "altscript")], checkedAt: Date())
        let view = drawingView(text: "国際連合教育科学文化機関", data: data, fontSize: 53)
        assertNoOverlaps(view.layout(width: 100), width: 100)
    }

    func testSwiftUIEnabledDisabledAndAbsentTranscription() throws {
        for (enabled, furigana, expectedNative) in [(true, Optional(data), true), (false, Optional(data), false), (true, nil, false)] {
            let host = UIHostingController(rootView: FuriganaText(text: text, furigana: furigana, showsFurigana: enabled))
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 240, height: 300)
            window.rootViewController = host
            window.isHidden = false
            host.view.layoutIfNeeded()
            XCTAssertEqual(containsDrawingView(host.view), expectedNative)
            window.isHidden = true
        }
    }

    func testLightAndDarkRenderedVariants() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let view = drawingView(text: text, data: data)
            view.overrideUserInterfaceStyle = style
            attach(view, width: 240, name: style == .light ? "Light" : "Dark")
            XCTAssertEqual(view.accessibilityLabel, text)
        }
    }

    private func drawingView(text: String, data: ExampleFurigana, fontSize: CGFloat = 17) -> FuriganaDrawingView {
        let view = FuriganaDrawingView()
        view.configure(segments: data.segments(for: text), fontSize: fontSize,
                       textColor: .label, readingColor: .secondaryLabel)
        return view
    }

    private func assertNoOverlaps(_ layout: FuriganaDrawingView.TextLayout, width: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        var previous: FuriganaDrawingView.Placement?
        for placement in layout.placements {
            XCTAssertGreaterThanOrEqual(placement.origin.x, 0, file: file, line: line)
            XCTAssertLessThanOrEqual(placement.origin.x + placement.width, width + 0.01, file: file, line: line)
            XCTAssertLessThan(placement.origin.y, layout.height, file: file, line: line)
            if let previous, placement.origin.y == previous.origin.y {
                XCTAssertGreaterThanOrEqual(placement.origin.x + 0.01, previous.origin.x + previous.width, file: file, line: line)
            }
            previous = placement
        }
    }

    private func containsDrawingView(_ view: UIView) -> Bool {
        view is FuriganaDrawingView || view.subviews.contains(where: containsDrawingView)
    }

    private func attach(_ view: FuriganaDrawingView, width: CGFloat, name: String) {
        view.frame = CGRect(x: 0, y: 0, width: width, height: view.layout(width: width).height)
        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { context in
            view.layer.render(in: context.cgContext)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
