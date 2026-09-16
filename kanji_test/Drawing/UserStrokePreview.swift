import SwiftUI

struct UserStrokePreview: View {
    let strokes: [[CGPoint]]

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / canonicalSize
            context.scaleBy(x: scale, y: scale)

            for stroke in strokes {
                context.stroke(
                    path(for: stroke),
                    with: .color(AppPalette.ink),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
            }
        }
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
}
