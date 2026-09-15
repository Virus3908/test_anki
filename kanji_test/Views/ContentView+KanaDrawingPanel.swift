import SwiftUI

extension ContentView {
    func kanaDrawingPanel(for kanaCard: KanaStudyCard, panelHeight: CGFloat) -> some View {
        let boardSide = drawingBoardSide(for: panelHeight)
        let expectedCard = kanjiCard(for: kanaCard)

        return VStack(spacing: 8) {
            let isCurrentCardAnswered = currentSessionRating() != nil

            ZStack {
                DrawingBoard(
                    drawnStrokes: $trainingSession.drawnStrokes,
                    currentStroke: $trainingSession.currentStroke,
                    expectedStrokes: expectedStrokesForCurrentCard(expectedCard),
                    feedback: trainingSession.feedback,
                    onStrokeFinished: {
                        handleGuidedStrokeFinished(expectedCard)
                    }
                )
                .frame(width: boardSide, height: boardSide)

                VStack {
                    HStack {
                        Button {
                            clearCurrentDrawing(expected: expectedCard)
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
                        undoCurrentStroke(expected: expectedCard)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(trainingSession.drawnStrokes.isEmpty)

                    Spacer()

                    Button {
                        advanceGuidedStrokeOrReveal(expectedCard)
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
                        ratingActionButton(
                            "-",
                            color: ratingButtonColor(for: .again, hasFeedback: !trainingSession.feedback.isEmpty, isAnswered: isCurrentCardAnswered),
                            isSelected: currentSessionRating() == .again
                        ) {
                            applyKanaReview(.again)
                        }
                        ratingActionButton(
                            "~",
                            color: ratingButtonColor(for: .hard, hasFeedback: !trainingSession.feedback.isEmpty, isAnswered: isCurrentCardAnswered),
                            isSelected: currentSessionRating() == .hard
                        ) {
                            applyKanaReview(.hard)
                        }
                        ratingActionButton(
                            "+",
                            color: ratingButtonColor(for: .good, hasFeedback: !trainingSession.feedback.isEmpty, isAnswered: isCurrentCardAnswered),
                            isSelected: currentSessionRating() == .good
                        ) {
                            applyKanaReview(.good)
                        }
                    }
                }
                .disabled(trainingSession.feedback.isEmpty && !isCurrentCardAnswered)

                Spacer(minLength: 12)

                Button { moveToNextCard() } label: { Image(systemName: "chevron.right") }
                    .disabled(trainingSession.currentIndex >= kanaCards.count - 1 || trainingSession.isPreparingCard)
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
