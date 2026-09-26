import SwiftUI

extension TrainingView {
    func drawingPanel(for card: KanjiCard, panelHeight: CGFloat) -> some View {
        @Bindable var drawingSession = trainingSession.drawingSession
        let hasStrokeOrder = !card.strokes.isEmpty
        let boardSide = drawingBoardSide(for: panelHeight - (hasStrokeOrder ? 0 : 48))

        return VStack(spacing: 8) {
            if !hasStrokeOrder {
                HStack {
                    Text("Для этого кандзи нет образца черт. Оцените ответ самостоятельно.")
                        .font(.caption)
                        .lineLimit(2)
                    Button("Ответ") { revealDrawingAnswer() }
                }
            }

            ZStack {
                DrawingBoard(
                    drawnStrokes: $drawingSession.drawnStrokes,
                    currentStroke: $drawingSession.currentStroke,
                    expectedStrokes: expectedStrokesForCurrentCard(card),
                    feedback: drawingSession.feedback,
                    onStrokeFinished: {
                        handleGuidedStrokeFinished(card)
                    }
                )
                .frame(width: boardSide, height: boardSide)

                VStack {
                    HStack {
                        Button {
                            clearCurrentDrawing(expected: card)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(drawingSession.drawnStrokes.isEmpty && drawingSession.currentStroke.isEmpty)

                        Spacer()

                        feedbackInfoButton(items: drawingSession.feedback)
                            .disabled(drawingSession.feedback.isEmpty)
                            .tint(drawingSession.feedback.isEmpty ? AppPalette.mutedText : AppPalette.accent)
                    }

                    Spacer()
                }

                HStack {
                    Button {
                        undoCurrentStroke(expected: card)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(drawingSession.drawnStrokes.isEmpty)

                    Spacer()

                Button {
                    advanceGuidedStrokeOrReveal(card)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.accent)
                }
            }
            .frame(maxWidth: .infinity, minHeight: boardSide)
            .buttonStyle(.bordered)
            .tint(AppPalette.accent)
            .font(.title3.weight(.semibold))

            reviewControls()

        }
        .frame(height: panelHeight)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(AppPalette.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppPalette.border.opacity(0.65))
                .frame(height: 1)
        }
    }

}
