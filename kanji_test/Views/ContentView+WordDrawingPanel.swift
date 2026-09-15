import SwiftUI

extension ContentView {
    func wordDrawingPanel(for wordCard: WordStudyCard, currentKanji: KanjiCard, panelHeight: CGFloat) -> some View {
        let boardSide = drawingBoardSide(for: panelHeight)

        return VStack(spacing: 8) {
            let isCurrentCardAnswered = currentSessionRating() != nil

            ZStack {
                DrawingBoard(
                    drawnStrokes: $trainingSession.drawnStrokes,
                    currentStroke: $trainingSession.currentStroke,
                    expectedStrokes: expectedStrokesForCurrentWordKanji(currentKanji),
                    feedback: currentWordFeedback,
                    onStrokeFinished: nil
                )
                .frame(width: boardSide, height: boardSide)

                VStack {
                    HStack {
                        Button {
                            clearCurrentWordDrawing(wordCard, currentKanji: currentKanji)
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
                        undoCurrentWordStroke(wordCard, currentKanji: currentKanji)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(trainingSession.drawnStrokes.isEmpty)

                    Spacer()

                    Button {
                        advanceWordKanjiOrCheck(wordCard)
                    } label: {
                    Image(systemName: trainingSession.currentWordKanjiIndex < wordCard.kanjiCards.count - 1 ? "arrow.right.circle.fill" : "checkmark.circle.fill")
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
                            applyWordReview(.again)
                        }
                        ratingActionButton(
                            "~",
                            color: ratingButtonColor(for: .hard, hasFeedback: !trainingSession.feedback.isEmpty, isAnswered: isCurrentCardAnswered),
                            isSelected: currentSessionRating() == .hard
                        ) {
                            applyWordReview(.hard)
                        }
                        ratingActionButton(
                            "+",
                            color: ratingButtonColor(for: .good, hasFeedback: !trainingSession.feedback.isEmpty, isAnswered: isCurrentCardAnswered),
                            isSelected: currentSessionRating() == .good
                        ) {
                            applyWordReview(.good)
                        }
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
                .disabled(trainingSession.currentIndex >= wordCards.count - 1 || trainingSession.isPreparingCard)
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
