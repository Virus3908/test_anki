import SwiftUI

extension ContentView {
    func drawingPanel(for card: KanjiCard, panelHeight: CGFloat) -> some View {
        let boardSide = drawingBoardSide(for: panelHeight)

        return VStack(spacing: 8) {
            let isCurrentCardAnswered = currentSessionRating() != nil

            ZStack {
                DrawingBoard(
                    drawnStrokes: $trainingSession.drawnStrokes,
                    currentStroke: $trainingSession.currentStroke,
                    expectedStrokes: expectedStrokesForCurrentCard(card),
                    feedback: trainingSession.feedback,
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
                        .disabled(trainingSession.drawnStrokes.isEmpty && trainingSession.currentStroke.isEmpty)

                        Spacer()

                        feedbackInfoButton(items: trainingSession.feedback)
                            .disabled(trainingSession.feedback.isEmpty)
                            .tint(trainingSession.feedback.isEmpty ? AppPalette.mutedText : AppPalette.accent)
                    }

                    Spacer()
                }

                HStack {
                    Button {
                        undoCurrentStroke(expected: card)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(trainingSession.drawnStrokes.isEmpty)

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

            HStack(spacing: 8) {
                Button {
                    moveToPreviousCard()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(trainingSession.currentIndex <= 0 || trainingSession.isPreparingCard)

                Spacer(minLength: 12)

                VStack(spacing: 4) {
                    sessionAnswerLabel()

                    HStack(spacing: 10) {
                        reviewButton("-", rating: .again, card: card)
                        reviewButton("~", rating: .hard, card: card)
                        reviewButton("+", rating: .good, card: card)
                    }
                }
                .disabled(trainingSession.feedback.isEmpty && !isCurrentCardAnswered)

                Spacer(minLength: 12)

                Button {
                    moveToNextCard()
                } label: {
                    if trainingSession.isPreparingCard {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "chevron.right")
                    }
                }
                .disabled(trainingSession.currentIndex >= cards.count - 1 || trainingSession.isPreparingCard)
            }
            .buttonStyle(.bordered)
            .tint(AppPalette.accent)
            .font(.title3.weight(.semibold))
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
