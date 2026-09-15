import SwiftUI

extension ContentView {
    func cardSwipeGesture() -> some Gesture {
        DragGesture(minimumDistance: 35)
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height
                guard abs(width) > abs(height) * 1.4, abs(width) > 70 else {
                    return
                }

                if width < 0 {
                    moveToNextCard()
                } else {
                    moveToPreviousCard()
                }
            }
    }

    func headerControls() -> some View {
        HStack(spacing: 12) {
            Button("", systemImage: "square.grid.2x2") {
                hasStartedTraining = false
            }

            Text(trainingTitle)
                .font(.headline)

            Spacer()

            Text("Закреплено \(sessionCompletedCards) / \(sessionTotalCards)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppPalette.secondaryText)
                .frame(minWidth: 128, alignment: .trailing)
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.accent)
    }

}
