import SwiftUI

struct DrawingBoard: View {
    @Binding var drawnStrokes: [[CGPoint]]
    @Binding var currentStroke: [CGPoint]

    let expectedStrokes: [KanjiStroke]
    let feedback: [StrokeFeedback]
    let onStrokeFinished: (() -> Void)?

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                drawGuides(in: &context, size: size)
                let scale = size.width / canonicalSize
                context.scaleBy(x: scale, y: scale)

                for (index, stroke) in expectedStrokes.enumerated() {
                    let severity = severityForExpectedStroke(at: index)
                    drawExpectedStroke(stroke, severity: severity, in: &context)
                }

                for (index, stroke) in drawnStrokes.enumerated() {
                    context.stroke(
                        path(for: stroke),
                        with: .color(colorForActualStroke(at: index)),
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                    )
                }

                context.stroke(path(for: currentStroke), with: .color(AppPalette.accent), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            }
            .background(AppPalette.surface)
            .border(AppPalette.border.opacity(0.65))
            .gesture(dragGesture(size: proxy.size))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func drawExpectedStroke(_ stroke: KanjiStroke, severity: StrokeFeedbackSeverity, in context: inout GraphicsContext) {
        guard severity.requiresCorrectionOverlay else {
            context.stroke(
                SVGPathParser.path(from: stroke.pathData),
                with: .color(AppPalette.expectedCorrect.opacity(0.16)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
            )
            return
        }

        let markerColor = severity.expectedStrokeColor
        context.stroke(
            SVGPathParser.path(from: stroke.pathData),
            with: .color(markerColor.opacity(0.36)),
            style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round)
        )

        let startRect = CGRect(x: stroke.startPoint.x - 2.1, y: stroke.startPoint.y - 2.1, width: 4.2, height: 4.2)
        context.fill(Path(ellipseIn: startRect), with: .color(markerColor.opacity(0.85)))
    }

    private func severityForExpectedStroke(at index: Int) -> StrokeFeedbackSeverity {
        feedback.first { $0.strokeIndex == index }?.severity ?? .good
    }

    private func colorForActualStroke(at index: Int) -> Color {
        feedback.first { $0.strokeIndex == index }?.severity.actualStrokeColor ?? AppPalette.ink
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if currentStroke.isEmpty {
                    currentStroke.append(normalized(value.startLocation, in: size))
                }

                currentStroke.append(normalized(value.location, in: size))
            }
            .onEnded { _ in
                if currentStroke.count > 2 {
                    drawnStrokes.append(simplified(currentStroke))
                    onStrokeFinished?()
                }

                currentStroke.removeAll()
            }
    }

    private func normalized(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let side = max(size.width, 1)
        return CGPoint(
            x: min(max(point.x / side * canonicalSize, 0), canonicalSize),
            y: min(max(point.y / side * canonicalSize, 0), canonicalSize)
        )
    }

    private func simplified(_ points: [CGPoint]) -> [CGPoint] {
        var result: [CGPoint] = []

        for index in stride(from: 0, to: points.count, by: 3) {
            result.append(points[index])
        }

        if result.last != points.last, let last = points.last {
            result.append(last)
        }

        return result
    }

    private func path(for points: [CGPoint]) -> Path {
        var path = Path()

        guard let first = points.first else {
            return path
        }

        path.move(to: first)

        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        return path
    }

    private func drawGuides(in context: inout GraphicsContext, size: CGSize) {
        var guides = Path()
        guides.move(to: CGPoint(x: size.width / 2, y: 0))
        guides.addLine(to: CGPoint(x: size.width / 2, y: size.height))
        guides.move(to: CGPoint(x: 0, y: size.height / 2))
        guides.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        context.stroke(guides, with: .color(AppPalette.border.opacity(0.35)), lineWidth: 1)
    }
}
