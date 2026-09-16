import SwiftUI

struct StrokeStepStrip: View {
    let strokes: [KanjiStroke]
    var spacing: CGFloat = 4

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 41, maximum: 41), spacing: spacing)
        ]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
            ForEach(strokes, id: \.order) { stroke in
                StrokeStepView(strokes: strokes, visibleCount: stroke.order)
                    .frame(width: 41, height: 41)
            }
        }
    }
}

struct StrokeStepView: View {
    let strokes: [KanjiStroke]
    let visibleCount: Int

    var body: some View {
        Canvas { context, size in
            drawGuides(in: &context, size: size)
            let scale = min(size.width, size.height) / canonicalSize
            context.scaleBy(x: scale, y: scale)

            for stroke in strokes.prefix(visibleCount) {
                let color = stroke.order == visibleCount ? AppPalette.correction : AppPalette.ink.opacity(0.28)
                context.stroke(
                    SVGPathParser.path(from: stroke.pathData),
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .background(AppPalette.surface)
        .border(AppPalette.border.opacity(0.65))
        .overlay(alignment: .topLeading) {
            Text("\(visibleCount)")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(AppPalette.correction)
                .padding(2)
        }
    }

    private func drawGuides(in context: inout GraphicsContext, size: CGSize) {
        var guides = Path()
        guides.move(to: CGPoint(x: size.width / 2, y: 0))
        guides.addLine(to: CGPoint(x: size.width / 2, y: size.height))
        guides.move(to: CGPoint(x: 0, y: size.height / 2))
        guides.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        context.stroke(guides, with: .color(AppPalette.border.opacity(0.25)), lineWidth: 1)
    }
}
