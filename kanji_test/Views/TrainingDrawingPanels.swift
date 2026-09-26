import SwiftUI

// Shared training-screen building blocks, extracted from TrainingView so the
// SRS training screen and the endless custom-training screen render
// identically: rating bar, drawing panels, word strip, header and the
// kana→kanji card mapping used by the drawing panels.

// MARK: - Rating bar

@MainActor
struct TrainingRatingBar: View {
    let isAnswerVisible: Bool
    var isPreparingCard: Bool = false
    var intervalLabel: (ReviewRating) -> String = { _ in "" }
    let onRate: (ReviewRating) -> Void

    static func buttonColor(for rating: ReviewRating) -> Color {
        switch rating {
        case .again: return AppPalette.correction
        case .hard: return AppPalette.warning
        case .good: return AppPalette.success
        case .easy: return AppPalette.accent
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ReviewRating.allCases) { rating in
                Button {
                    onRate(rating)
                } label: {
                    VStack(spacing: 3) {
                        Text(rating.title).font(.caption.weight(.bold))
                        let interval = intervalLabel(rating)
                        if !interval.isEmpty { Text(interval).font(.caption2) }
                    }
                    .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Self.buttonColor(for: rating))
                .disabled(!isAnswerVisible || isPreparingCard)
            }
        }
    }
}

// MARK: - Feedback info

@MainActor
struct FeedbackInfoButton: View {
    let items: [StrokeFeedback]
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Проверка")
                    .font(.headline)
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(items) { item in
                            Text(item.message)
                                .font(.footnote)
                                .foregroundStyle(item.severity.textColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
            .padding(14)
            .frame(width: 300, alignment: .leading)
            .background(AppPalette.surface)
            .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - Panel metrics

/// Non-generic namespace for the shared panel-size math. External call
/// sites reference these without binding the panels' generic `Controls`
/// parameter (unbound static references on generic types fail to infer
/// on this toolchain).
enum TrainingDrawingPanelMetrics {
    static func drawingPanelHeight(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.42, 310), 355)
    }

    static func drawingBoardSide(for panelHeight: CGFloat) -> CGFloat {
        min(max(panelHeight - 132, 160), 205)
    }
}

// MARK: - Kanji drawing panel

@MainActor
struct KanjiDrawingPanel<Controls: View>: View {
    let drawingSession: DrawingSessionViewModel
    let expectedCard: KanjiCard
    let panelHeight: CGFloat
    var isGuided: Bool = false
    let onStrokeFinished: () -> Void
    let onReveal: () -> Void
    let onAdvance: () -> Void
    let controls: Controls

    init(
        drawingSession: DrawingSessionViewModel,
        expectedCard: KanjiCard,
        panelHeight: CGFloat,
        isGuided: Bool = false,
        onStrokeFinished: @escaping () -> Void,
        onReveal: @escaping () -> Void,
        onAdvance: @escaping () -> Void,
        @ViewBuilder controls: () -> Controls
    ) {
        self.drawingSession = drawingSession
        self.expectedCard = expectedCard
        self.panelHeight = panelHeight
        self.isGuided = isGuided
        self.onStrokeFinished = onStrokeFinished
        self.onReveal = onReveal
        self.onAdvance = onAdvance
        self.controls = controls()
    }

    var body: some View {
        @Bindable var session = drawingSession
        let hasStrokeOrder = !expectedCard.strokes.isEmpty
        let boardSide = TrainingDrawingPanelMetrics.drawingBoardSide(for: panelHeight - (hasStrokeOrder ? 0 : 48))

        VStack(spacing: 8) {
            if !hasStrokeOrder {
                HStack {
                    Text("Для этого кандзи нет образца черт. Оцените ответ самостоятельно.")
                        .font(.caption)
                        .lineLimit(2)
                    Button("Ответ") { onReveal() }
                }
            }

            ZStack {
                DrawingBoard(
                    drawnStrokes: $session.drawnStrokes,
                    currentStroke: $session.currentStroke,
                    expectedStrokes: session.expectedStrokes(for: expectedCard, isGuided: isGuided),
                    feedback: session.feedback,
                    onStrokeFinished: onStrokeFinished
                )
                .frame(width: boardSide, height: boardSide)

                VStack {
                    HStack {
                        Button {
                            session.clearDrawing(expected: expectedCard)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(session.drawnStrokes.isEmpty && session.currentStroke.isEmpty)

                        Spacer()

                        FeedbackInfoButton(items: session.feedback, isPresented: $session.showsFeedbackInfo)
                            .disabled(session.feedback.isEmpty)
                            .tint(session.feedback.isEmpty ? AppPalette.mutedText : AppPalette.accent)
                    }

                    Spacer()
                }

                HStack {
                    Button {
                        session.undoStroke(expected: expectedCard)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(session.drawnStrokes.isEmpty)

                    Spacer()

                    Button {
                        onAdvance()
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

            controls
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

// MARK: - Word drawing panel

@MainActor
struct WordDrawingPanel<Controls: View>: View {
    let drawingSession: DrawingSessionViewModel
    let wordCard: WordStudyCard
    let currentKanji: KanjiCard
    let panelHeight: CGFloat
    var isGuided: Bool = false
    let onStrokeFinished: () -> Void
    let onReveal: () -> Void
    let onAdvance: () -> Void
    let controls: Controls

    init(
        drawingSession: DrawingSessionViewModel,
        wordCard: WordStudyCard,
        currentKanji: KanjiCard,
        panelHeight: CGFloat,
        isGuided: Bool = false,
        onStrokeFinished: @escaping () -> Void,
        onReveal: @escaping () -> Void,
        onAdvance: @escaping () -> Void,
        @ViewBuilder controls: () -> Controls
    ) {
        self.drawingSession = drawingSession
        self.wordCard = wordCard
        self.currentKanji = currentKanji
        self.panelHeight = panelHeight
        self.isGuided = isGuided
        self.onStrokeFinished = onStrokeFinished
        self.onReveal = onReveal
        self.onAdvance = onAdvance
        self.controls = controls()
    }

    var body: some View {
        @Bindable var session = drawingSession
        let boardSide = TrainingDrawingPanelMetrics.drawingBoardSide(
            for: panelHeight - (wordCard.hasCompleteDrawingResources ? 0 : 48)
        )

        VStack(spacing: 8) {
            if !wordCard.hasCompleteDrawingResources {
                HStack {
                    Text("Для части символов нет образца черт. Оцени ответ самостоятельно.")
                        .font(.caption)
                        .lineLimit(2)
                    Button("Ответ") { onReveal() }
                }
            }

            ZStack {
                DrawingBoard(
                    drawnStrokes: $session.drawnStrokes,
                    currentStroke: $session.currentStroke,
                    expectedStrokes: session.expectedWordStrokes(for: currentKanji, isGuided: isGuided),
                    feedback: session.currentWordFeedback,
                    onStrokeFinished: onStrokeFinished
                )
                .frame(width: boardSide, height: boardSide)

                VStack {
                    HStack {
                        Button {
                            session.clearCurrentWordDrawing(wordCard, currentKanji: currentKanji)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(session.drawnStrokes.isEmpty && session.currentStroke.isEmpty)

                        Spacer()

                        FeedbackInfoButton(items: session.feedback, isPresented: $session.showsFeedbackInfo)
                            .disabled(session.feedback.isEmpty)
                            .tint(session.feedback.isEmpty ? AppPalette.mutedText : AppPalette.accent)
                    }

                    Spacer()
                }

                HStack {
                    Button {
                        session.undoCurrentWordStroke(wordCard, currentKanji: currentKanji)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(session.drawnStrokes.isEmpty)

                    Spacer()

                    Button {
                        onAdvance()
                    } label: {
                        Image(systemName: session.currentWordKanjiIndex < wordCard.kanjiCards.count - 1
                              ? "arrow.right.circle.fill"
                              : "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.accent)
                }
            }
            .frame(maxWidth: .infinity, minHeight: boardSide)
            .buttonStyle(.bordered)
            .tint(AppPalette.accent)
            .font(.title3.weight(.semibold))

            controls
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

// MARK: - Completed word strip

@MainActor
struct CompletedWordStrip: View {
    let wordCard: WordStudyCard
    let currentKanjiIndex: Int
    let drawnStrokes: [[CGPoint]]
    let completedDrawings: [[[CGPoint]]]
    let isAnswerVisible: Bool
    /// True when the front side layout already shows the word itself, so the
    /// strip may reveal kanji characters even before the answer is visible.
    let isKanjiTextShown: Bool
    let onSelectKanji: (Int) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            items

            ScrollView(.horizontal) {
                items
            }
            .scrollIndicators(.hidden)
        }
        .padding(8)
        .background(
            AppPalette.surface,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppPalette.border.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: AppPalette.text.opacity(0.12), radius: 8, y: 3)
    }

    private var items: some View {
        HStack(spacing: 8) {
            ForEach(wordCard.kanjiCards.enumerated(), id: \.offset) { index, kanjiCard in
                let isSelected = index == currentKanjiIndex
                ZStack {
                    if isSelected && !drawnStrokes.isEmpty {
                        UserStrokePreview(strokes: drawnStrokes)
                    } else if index < completedDrawings.count {
                        UserStrokePreview(strokes: completedDrawings[index])
                    } else if isAnswerVisible || isKanjiTextShown {
                        Text(kanjiCard.kanji)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(isAnswerVisible ? AppPalette.text : AppPalette.secondaryText)
                    } else {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(index == currentKanjiIndex ? AppPalette.accent : AppPalette.mutedText)
                    }
                }
                .frame(width: 34, height: 34)
                .background(AppPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? AppPalette.accent : AppPalette.border.opacity(0.45),
                                lineWidth: isSelected ? 2 : 1)
                )
                .contentShape(Rectangle())
                .onTapGesture { onSelectKanji(index) }
            }
        }
    }
}

// MARK: - Shared training header

@MainActor
struct TrainingHeaderView: View {
    let title: String
    let subtitle: String
    let onFinish: () -> Void
    var onExclude: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 12) {
                Button {
                    onFinish()
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .frame(width: 34, height: 30)
                }

                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if let onExclude {
                    Button {
                        onExclude()
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .accessibilityLabel("Исключить карточку из тренировок")
                }
            }

            Text(subtitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppPalette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.accent)
    }
}

// MARK: - Kana → kanji card mapping for drawing panels

extension CardContentRendering {
    /// Maps a kana card onto the kanji-card shape the drawing panel expects,
    /// reusing the kana stroke presets as the expected stroke order.
    func kanjiCard(for kanaCard: KanaStudyCard) -> KanjiCard {
        KanjiCard(
            kanji: kanaCard.character,
            meanings: [kanaCard.reading],
            onyomi: [],
            kunyomi: [kanaCard.reading],
            examples: [],
            source: KanjiSource(name: "KanjiVG", file: "kana", license: "KanjiVG: Creative Commons Attribution-Share Alike 3.0"),
            strokes: kanaCard.strokes,
            translationState: "ru-system"
        )
    }
}
