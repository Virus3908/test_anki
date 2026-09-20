import SwiftUI

extension TrainingView {
    func wordDrawingPanel(for wordCard: WordStudyCard, currentKanji: KanjiCard, panelHeight: CGFloat) -> some View {
        @Bindable var drawingSession = trainingSession.drawingSession
        let boardSide = drawingBoardSide(for: panelHeight - (wordCard.hasCompleteDrawingResources ? 0 : 48))

        return VStack(spacing: 8) {
            if !wordCard.hasCompleteDrawingResources {
                HStack {
                    Text("Для части символов нет образца черт. Оцени ответ самостоятельно.")
                        .font(.caption)
                        .lineLimit(2)
                    Button("Ответ") { revealDrawingAnswer() }
                }
            }

            ZStack {
                DrawingBoard(
                    drawnStrokes: $drawingSession.drawnStrokes,
                    currentStroke: $drawingSession.currentStroke,
                    expectedStrokes: expectedStrokesForCurrentWordKanji(currentKanji),
                    feedback: currentWordFeedback,
                    onStrokeFinished: {
                        handleGuidedWordStrokeFinished(wordCard)
                    }
                )
                .frame(width: boardSide, height: boardSide)

                VStack {
                    HStack {
                        Button {
                            clearCurrentWordDrawing(wordCard, currentKanji: currentKanji)
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
                        undoCurrentWordStroke(wordCard, currentKanji: currentKanji)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(drawingSession.drawnStrokes.isEmpty)

                    Spacer()

                    Button {
                        advanceWordKanjiOrCheck(wordCard)
                    } label: {
                    Image(systemName: drawingSession.currentWordKanjiIndex < wordCard.kanjiCards.count - 1 ? "arrow.right.circle.fill" : "checkmark.circle.fill")
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
