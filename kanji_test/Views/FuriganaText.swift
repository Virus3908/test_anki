import CoreText
import SwiftUI
import UIKit

/// Native, wrapping ruby text. Copy always uses the untouched sentence, never its reading.
struct FuriganaText: View {
    let text: String
    var furigana: ExampleFurigana? = nil
    var showsFurigana = true
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 17

    var body: some View {
        Group {
            if showsFurigana, let furigana,
               furigana.segments(for: text).contains(where: { $0.reading != nil }) {
                NativeFuriganaText(segments: furigana.segments(for: text), fontSize: fontSize)
                    .accessibilityLabel(text)
                    .accessibilityIdentifier(AccessibilityID.Examples.furigana)
                    .alignmentGuide(.firstTextBaseline) { _ in
                        UIFont.systemFont(ofSize: fontSize * 0.5).lineHeight + 2
                            + UIFont.systemFont(ofSize: fontSize).ascender
                    }
            } else {
                Text(text)
                    .accessibilityIdentifier(AccessibilityID.Examples.plain)
                    .foregroundStyle(AppPalette.text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .contextMenu {
            Button("Копировать предложение", systemImage: "doc.on.doc") { UIPasteboard.general.string = text }
        }
    }
}

private struct NativeFuriganaText: UIViewRepresentable {
    let segments: [FuriganaSegment]
    let fontSize: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func makeUIView(context: Context) -> FuriganaDrawingView {
        let view = FuriganaDrawingView()
        view.backgroundColor = .clear
        view.isAccessibilityElement = true
        view.accessibilityTraits = .staticText
        configure(view)
        return view
    }

    func updateUIView(_ view: FuriganaDrawingView, context: Context) {
        configure(view)
        // Reading the environment makes palette changes invalidate this representable.
        _ = colorScheme
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: FuriganaDrawingView, context: Context) -> CGSize? {
        // SwiftUI can measure a representable before updateUIView is called.
        // Always measure this sentence, not empty or previously rendered glyphs.
        configure(uiView)
        let proposedWidth = proposal.width ?? 320
        let width = proposedWidth.isFinite ? max(1, proposedWidth) : 320
        let layout = uiView.layout(width: width)
        // Report the occupied width, like SwiftUI Text, rather than consuming
        // the entire proposal and pushing an adjacent attribution button away.
        return CGSize(width: min(width, ceil(layout.width)), height: layout.height)
    }

    private func configure(_ view: FuriganaDrawingView) {
        view.configure(segments: segments, fontSize: fontSize,
                       textColor: UIColor(AppPalette.text), readingColor: UIColor(AppPalette.secondaryText))
    }
}

/// Core Text draws each explicit annotation as one unit. Its width reserves room for BOTH
/// base and reading, so adjacent readings cannot overlap. Unannotated text breaks by grapheme;
/// annotated words stay together, without inventing per-kanji readings.
final class FuriganaDrawingView: UIView {
    struct Glyph {
        let base: CTLine
        let ruby: CTLine?
        let baseWidth: CGFloat
        let rubyWidth: CGFloat
        var width: CGFloat { max(baseWidth, rubyWidth) }
    }
    struct Placement {
        let glyph: Glyph
        let origin: CGPoint
        let scale: CGFloat
        var width: CGFloat { glyph.width * scale }
    }
    struct TextLayout {
        let placements: [Placement]
        let height: CGFloat
        var width: CGFloat {
            placements.reduce(CGFloat.zero) { max($0, $1.origin.x + $1.width) }
        }
    }
    private var units: [[Glyph]] = []
    private var font = UIFont.systemFont(ofSize: 17)
    private var rubyFont = UIFont.systemFont(ofSize: 8.5)
    private var rubyHeight: CGFloat = 0
    private var configuredSegments: [FuriganaSegment]?
    private var configuredFontSize: CGFloat?
    private var configuredTextColor: UIColor?
    private var configuredReadingColor: UIColor?

    override var intrinsicContentSize: CGSize {
        let measured = layout(width: .greatestFiniteMagnitude)
        return CGSize(width: ceil(measured.width), height: measured.height)
    }

    func configure(segments: [FuriganaSegment], fontSize: CGFloat, textColor: UIColor, readingColor: UIColor) {
        guard configuredSegments != segments || configuredFontSize != fontSize
                || configuredTextColor != textColor || configuredReadingColor != readingColor else { return }
        configuredSegments = segments
        configuredFontSize = fontSize
        configuredTextColor = textColor
        configuredReadingColor = readingColor
        font = UIFont.systemFont(ofSize: fontSize)
        rubyFont = UIFont.systemFont(ofSize: fontSize * 0.5)
        rubyHeight = segments.contains { $0.reading != nil } ? rubyFont.lineHeight + 2 : 0
        accessibilityLabel = segments.map(\.text).joined()
        units = []
        var opening: [Glyph] = []
        let closingCharacters = "、。，．！？)]）］｝」』】〉》ぁぃぅぇぉっゃゅょァィゥェォッャュョー"
        let openingCharacters = "([（［｛「『【〈《"
        for segment in segments {
            let parts = segment.reading == nil ? segment.text.map(String.init) : [segment.text]
            for part in parts {
                if part == "\n" || part == "\r\n" || part == "\r" {
                    if !opening.isEmpty { units.append(opening); opening = [] }
                    units.append([])
                    continue
                }
                let base = line(part, font: font, color: textColor)
                let ruby = segment.reading.map { line($0, font: rubyFont, color: readingColor) }
                let glyph = Glyph(base: base, ruby: ruby, baseWidth: width(base), rubyWidth: ruby.map(width) ?? 0)
                if segment.reading == nil, openingCharacters.contains(part) {
                    opening.append(glyph)
                } else if segment.reading == nil, closingCharacters.contains(part), !units.isEmpty,
                          !units[units.count - 1].isEmpty, opening.isEmpty {
                    units[units.count - 1].append(glyph)
                } else {
                    units.append(opening + [glyph])
                    opening = []
                }
            }
        }
        if !opening.isEmpty { units.append(opening) }
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }

    func layout(width: CGFloat) -> TextLayout {
        let available = max(1, width)
        let rowHeight = font.lineHeight + rubyHeight + 3
        var x: CGFloat = 0
        var y: CGFloat = 0
        var placements: [Placement] = []
        for unit in units {
            if unit.isEmpty { x = 0; y += rowHeight; continue }
            let unitWidth = unit.reduce(CGFloat.zero) { $0 + $1.width }
            if x > 0, x + unitWidth > available { x = 0; y += rowHeight }
            // Pathological long single annotations fit the container as one unit.
            // No arbitrary splitting of a contextual reading across kanji.
            let scale = min(1, available / max(1, unitWidth))
            for glyph in unit {
                placements.append(Placement(glyph: glyph, origin: CGPoint(x: x, y: y), scale: scale))
                x += glyph.width * scale
            }
        }
        return TextLayout(placements: placements, height: units.isEmpty ? 0 : ceil(y + rowHeight))
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        for placement in layout(width: bounds.width).placements {
            let glyph = placement.glyph
            draw(glyph.base, width: glyph.baseWidth, placement: placement,
                 baseline: placement.origin.y + rubyHeight + font.ascender, context: context)
            if let ruby = glyph.ruby {
                draw(ruby, width: glyph.rubyWidth, placement: placement,
                     baseline: placement.origin.y + rubyFont.ascender, context: context)
            }
        }
        context.restoreGState()
    }

    private func draw(_ line: CTLine, width: CGFloat, placement: Placement, baseline: CGFloat, context: CGContext) {
        context.saveGState()
        context.translateBy(x: placement.origin.x + (placement.width - width * placement.scale) / 2,
                            y: bounds.height - baseline)
        context.scaleBy(x: placement.scale, y: 1)
        context.textPosition = .zero
        CTLineDraw(line, context)
        context.restoreGState()
    }

    private func line(_ text: String, font: UIFont, color: UIColor) -> CTLine {
        CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color]))
    }
    private func width(_ line: CTLine) -> CGFloat { CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) }
}

#Preview("Короткое и длинное предложения") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            let short = "学校は好き？"
            let data = ExampleFurigana(transcriptions: [TatoebaTranscription(text: "[学校|がっ|こう]は[好|す]き？", script: "Hrkt", type: "altscript")], checkedAt: Date())
            FuriganaText(text: short, furigana: data)
            FuriganaText(text: short, furigana: data, showsFurigana: false)
            FuriganaText(text: "読みのない例。")
            let long = String(repeating: "私は今日学校で勉強しています。", count: 8)
            let markup = String(repeating: "[私|わたし]は[今日|きょう][学校|がっ|こう]で[勉強|べん|きょう]しています。", count: 8)
            FuriganaText(text: long, furigana: ExampleFurigana(transcriptions: [TatoebaTranscription(text: markup, script: "Hrkt", type: "altscript")], checkedAt: Date()))
        }.padding()
    }.background(AppPalette.background)
}
