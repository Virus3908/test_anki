import SwiftUI

/// Endless practice screen over the picked card subset.
///
/// Mirrors the SRS training layout (flip card, drawing panels, rating bar,
/// speech) through the shared `TrainingDrawingPanels` components, but answers
/// only reorder the in-session queue — the daily SRS plan is never touched.
@MainActor
struct CustomTrainingView: View, CardContentRendering {
    let session: CustomTrainingSession
    let settings: StudyPreferences
    let translationState: TranslationViewModel
    let coordinator: StudyCoordinator
    let reviewStore: StudyProgressStore
    let onExit: () -> Void

    var onPractice: (PracticeSelection) -> Void = { _ in }
    var deckID: String? { session.deck?.id }
    var practiceMode: PracticeMode { session.deck?.mode ?? .kanji }

    @State private var drawingSession = DrawingSessionViewModel()
    @State private var speech = SpeechService()
    @State private var isFieldSettingsPresented = false
    @State private var fieldSettingsSide = BuiltInCardSide.front

    /// Changes whenever a new card is presented, including single-card
    /// requeues (same id, new answer count), so per-card tasks re-run.
    private var cardPresentationToken: String {
        "\(session.currentID ?? "none")-\(session.answersCount)"
    }

    private var accuracyText: String {
        session.answersCount == 0 ? "—" : "\(Int((session.accuracy * 100).rounded()))%"
    }

    var body: some View {
        ZStack {
            AppPalette.background.ignoresSafeArea()
            if session.isRunning {
                if practiceMode == .anki {
                    ankiTrainingArea
                } else {
                    drawingTrainingArea
                }
            } else {
                stoppedView
            }
        }
        .sheet(isPresented: $isFieldSettingsPresented) {
            BuiltInCardFieldSettingsView(
                settings: settings,
                deckID: deckID,
                mode: practiceMode,
                initialSide: fieldSettingsSide
            )
        }
        .onAppear(perform: applySpeechSettings)
        .onChange(of: settings.speechEnabled) { _, _ in applySpeechSettings() }
        .onChange(of: settings.speechVoiceIdentifier) { _, _ in applySpeechSettings() }
        .onChange(of: settings.speechRate) { _, _ in applySpeechSettings() }
        .onDisappear { speech.stop() }
        .task(id: cardPresentationToken) { speakFrontIfNeeded() }
    }

    // MARK: - Layout (mirrors TrainingView+Layout)

    private var drawingTrainingArea: some View {
        GeometryReader { proxy in
            let panelHeight = TrainingDrawingPanelMetrics.drawingPanelHeight(for: proxy.size)
            let showsWordStrip = practiceMode == .words
                && session.currentWordCard.flatMap { currentWordKanji(for: $0) } != nil

            ZStack(alignment: .bottom) {
                AppPalette.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 16) {
                            headerControls
                            cardArea
                        }
                        .padding(20)
                        .padding(.bottom, 12)
                        .foregroundStyle(AppPalette.text)
                    }
                    .id(cardPresentationToken)

                    drawingArea(panelHeight: panelHeight)
                }

                if showsWordStrip {
                    completedWordStrip
                        .padding(.horizontal, 20)
                        .padding(.bottom, panelHeight + 10)
                        .zIndex(2)
                }
            }
        }
    }

    private var ankiTrainingArea: some View {
        ZStack {
            AppPalette.background.ignoresSafeArea()
            VStack(spacing: 16) {
                headerControls

                if let card = session.currentAnkiCard {
                    AnkiCardContentView(card: card, answer: drawingSession.isAnswerVisible,
                                        translationState: translationState, language: meaningLanguage)
                        .id("\(card.id)-\(session.answersCount)")
                    learningStatusLabel(forReviewKey: card.reviewKey)
                }

                VStack(spacing: 12) {
                    Button(drawingSession.isAnswerVisible ? "Показать вопрос" : "Показать ответ") {
                        drawingSession.isAnswerVisible.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.accent)

                    ratingControls
                }
                .padding(16)
                .appSurfaceCard()
            }
            .padding(20)
            .foregroundStyle(AppPalette.text)
        }
    }

    private var headerControls: some View {
        TrainingHeaderView(
            title: session.deck?.title ?? "Кастом-тренировка",
            subtitle: "Круг \(session.round) · Ответов \(session.answersCount) · Точность \(accuracyText) · Серия \(session.currentStreak)",
            onFinish: onExit
        )
    }

    // MARK: - Card area

    @ViewBuilder private var cardArea: some View {
        switch practiceMode {
        case .kanji:
            if let card = session.currentKanjiCard {
                trainingCardShell {
                    kanjiCardFront(for: card)
                } back: {
                    cardBackContent(
                        for: card,
                        onShowAllFields: { presentFieldSettings(.back) },
                        onSpeak: { speech.speak(card.kanji) }
                    )
                }
            }
        case .kana:
            if let card = session.currentKanaCard {
                trainingCardShell {
                    kanaCardFront(for: card)
                } back: {
                    kanaCardBackContent(
                        for: card,
                        onShowAllFields: { presentFieldSettings(.back) },
                        onSpeak: { speech.speak(card.character) }
                    )
                }
            }
        case .words:
            if let card = session.currentWordCard {
                trainingCardShell {
                    wordCardFront(for: card)
                } back: {
                    studyCardBackShell(
                        reviewKey: card.reviewKey,
                        onShowAllFields: { presentFieldSettings(.back) },
                        onSpeak: { speech.speak(card.word) }
                    ) {
                        wordFullCardContent(for: card)
                    }
                }
            }
        case .anki:
            EmptyView()
        }
    }

    private func trainingCardShell<Front: View, Back: View>(
        @ViewBuilder front: () -> Front,
        @ViewBuilder back: () -> Back
    ) -> some View {
        ZStack {
            ScrollView {
                front()
            }
            .scrollIndicators(.hidden)
            .opacity(drawingSession.isAnswerVisible ? 0 : 1)
            .rotation3DEffect(.degrees(drawingSession.isAnswerVisible ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            ScrollView {
                back()
            }
            .scrollIndicators(.hidden)
            .opacity(drawingSession.isAnswerVisible ? 1 : 0)
            .rotation3DEffect(.degrees(drawingSession.isAnswerVisible ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .appSurfaceCard()
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.24)) {
                drawingSession.isAnswerVisible.toggle()
            }
        }
    }

    /// Local parity of TrainingView.studyCardFrontShell: same layout, footer
    /// and learning status, bound to this view's field-settings state.
    private func cardFrontShell<Fields: View>(
        fallbackPrompt: String,
        footerText: String,
        reviewKey: String,
        speechText: String,
        isTextSelectable: Bool = true,
        @ViewBuilder fields: () -> Fields
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Задание")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                Spacer()
                if !speechText.isEmpty {
                    CardHeaderActionButton(title: "Озвучить", systemImage: "speaker.wave.2.fill") {
                        speech.speak(speechText)
                    }
                }
                CardHeaderActionButton(title: "Все поля", systemImage: "list.bullet.rectangle") {
                    presentFieldSettings(.front)
                }
            }
            .foregroundStyle(AppPalette.secondaryText)

            fields()

            if cardFields(for: practiceMode, side: .front).isEmpty {
                Text(fallbackPrompt)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppPalette.text)
            }

            Spacer(minLength: 16)

            Text(footerText)
                .foregroundStyle(AppPalette.secondaryText)

            learningStatusLabel(forReviewKey: reviewKey)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(TextSelectionModeModifier(isEnabled: isTextSelectable))
        .sheet(isPresented: $isFieldSettingsPresented) {
            BuiltInCardFieldSettingsView(
                settings: settings,
                deckID: deckID,
                mode: practiceMode,
                initialSide: fieldSettingsSide
            )
        }
    }

    private func kanjiCardFront(for card: KanjiCard) -> some View {
        cardFrontShell(
            fallbackPrompt: card.strokes.isEmpty
                ? "Вспомни кандзи по памяти."
                : "Нарисуй кандзи по памяти.",
            footerText: card.strokes.isEmpty
                ? "Для этого кандзи нет локального образца черт."
                : "Проверка покажет оригинал и сравнение штрихов.",
            reviewKey: card.reviewKey,
            speechText: card.kanji
        ) {
            kanjiCardFields(cardFields(for: .kanji, side: .front), for: card)
        }
    }

    private func kanaCardFront(for card: KanaStudyCard) -> some View {
        cardFrontShell(
            fallbackPrompt: "Нарисуй знак каны по памяти.",
            footerText: "Проверка покажет оригинал и сравнение штрихов.",
            reviewKey: card.reviewKey,
            speechText: card.character,
            isTextSelectable: false
        ) {
            ForEach(cardFields(for: .kana, side: .front)) { field in
                kanaCardField(field, for: card)
            }
        }
    }

    private func wordCardFront(for card: WordStudyCard) -> some View {
        cardFrontShell(
            fallbackPrompt: "Нарисуй символы слова по памяти.",
            footerText: "Проверка покажет слово, чтение, перевод и состав.",
            reviewKey: card.reviewKey,
            speechText: card.word
        ) {
            ForEach(cardFields(for: .words, side: .front)) { field in
                wordCardField(field, for: card)
            }
        }
    }

    // MARK: - Drawing area

    private func drawingArea(panelHeight: CGFloat) -> some View {
        Group {
            switch practiceMode {
            case .kanji:
                if let card = session.currentKanjiCard {
                    kanjiDrawingArea(for: card, panelHeight: panelHeight)
                }
            case .kana:
                if let card = session.currentKanaCard {
                    kanaDrawingArea(for: card, panelHeight: panelHeight)
                }
            case .words:
                if let card = session.currentWordCard {
                    wordDrawingArea(for: card, panelHeight: panelHeight)
                }
            case .anki:
                EmptyView()
            }
        }
    }

    private func kanjiDrawingArea(for card: KanjiCard, panelHeight: CGFloat) -> some View {
        KanjiDrawingPanel(
            drawingSession: drawingSession,
            expectedCard: card,
            panelHeight: panelHeight,
            onStrokeFinished: { handleGuidedStrokeFinished(card) },
            onReveal: { revealDrawingAnswer() },
            onAdvance: { advanceStrokeOrReveal(card) }
        ) {
            ratingControls
        }
    }

    private func kanaDrawingArea(for card: KanaStudyCard, panelHeight: CGFloat) -> some View {
        let expectedCard = kanjiCard(for: card)

        return KanjiDrawingPanel(
            drawingSession: drawingSession,
            expectedCard: expectedCard,
            panelHeight: panelHeight,
            onStrokeFinished: { handleGuidedStrokeFinished(expectedCard) },
            onReveal: { revealDrawingAnswer() },
            onAdvance: { advanceStrokeOrReveal(expectedCard) }
        ) {
            ratingControls
        }
    }

    @ViewBuilder private func wordDrawingArea(for card: WordStudyCard, panelHeight: CGFloat) -> some View {
        if let currentKanji = currentWordKanji(for: card) {
            WordDrawingPanel(
                drawingSession: drawingSession,
                wordCard: card,
                currentKanji: currentKanji,
                panelHeight: panelHeight,
                onStrokeFinished: { handleGuidedWordStrokeFinished(card) },
                onReveal: { revealDrawingAnswer() },
                onAdvance: { advanceWordKanjiOrCheck(card) }
            ) {
                ratingControls
            }
        } else {
            VStack(spacing: 12) {
                if !drawingSession.isAnswerVisible {
                    Button("Показать ответ") {
                        revealDrawingAnswer()
                    }
                    .buttonStyle(.borderedProminent)
                }
                ratingControls
            }
            .padding(16)
            .background(AppPalette.surface)
        }
    }

    private var completedWordStrip: some View {
        Group {
            if let card = session.currentWordCard {
                CompletedWordStrip(
                    wordCard: card,
                    currentKanjiIndex: drawingSession.currentWordKanjiIndex,
                    drawnStrokes: drawingSession.drawnStrokes,
                    completedDrawings: drawingSession.completedWordDrawings,
                    isAnswerVisible: drawingSession.isAnswerVisible,
                    isKanjiTextShown: cardFields(for: .words, side: .front).contains(.word),
                    onSelectKanji: { drawingSession.selectWordKanji(at: $0, in: card) }
                )
            }
        }
    }

    private func currentWordKanji(for wordCard: WordStudyCard) -> KanjiCard? {
        wordCard.kanjiCards[safe: drawingSession.currentWordKanjiIndex]
    }

    // MARK: - Rating

    private var ratingControls: some View {
        TrainingRatingBar(
            isAnswerVisible: drawingSession.isAnswerVisible,
            intervalLabel: { _ in "" }
        ) { rating in
            submit(rating)
        }
    }

    // MARK: - Stopped state

    private var stoppedView: some View {
        VStack(spacing: 14) {
            Text("Тренировка остановлена")
                .font(.headline)
            Text("Кастом-тренировка не сохраняет прогресс и не влияет на расписание повторений.")
                .font(.caption)
                .foregroundStyle(AppPalette.secondaryText)
                .multilineTextAlignment(.center)
            primaryActionButton(title: "Вернуться к колоде", systemImage: "chevron.left", action: onExit)
        }
        .padding(24)
    }

    // MARK: - Actions

    private func revealDrawingAnswer() {
        withAnimation(.easeInOut(duration: 0.24)) {
            drawingSession.revealAnswer()
        }
    }

    private func handleGuidedStrokeFinished(_ card: KanjiCard) {
        let shouldReveal = drawingSession.handleGuidedStrokeFinished(card, isGuided: false)
        if shouldReveal {
            revealDrawingAnswer()
        }
    }

    private func advanceStrokeOrReveal(_ card: KanjiCard) {
        let shouldReveal = drawingSession.advanceGuidedStrokeOrReveal(card, isGuided: false)
        if shouldReveal {
            revealDrawingAnswer()
        }
    }

    private func handleGuidedWordStrokeFinished(_ wordCard: WordStudyCard) {
        let shouldReveal = drawingSession.handleGuidedWordStrokeFinished(wordCard, isGuided: false)
        if shouldReveal {
            revealDrawingAnswer()
        }
    }

    private func advanceWordKanjiOrCheck(_ wordCard: WordStudyCard) {
        let shouldReveal = drawingSession.advanceWordKanjiOrCheck(wordCard)
        if shouldReveal {
            revealDrawingAnswer()
        }
    }

    private func submit(_ rating: ReviewRating) {
        speech.stop()
        withAnimation(.easeInOut(duration: 0.24)) {
            session.submit(rating)
        }
        // The endless queue can requeue the same card id, so the drawing
        // state is reset here rather than on a card-id change.
        drawingSession.resetCurrentAnswer()
        drawingSession.resetWordDrawingState(resetKanjiIndex: true)
    }

    private func presentFieldSettings(_ side: BuiltInCardSide) {
        fieldSettingsSide = side
        isFieldSettingsPresented = true
    }

    private func applySpeechSettings() {
        speech.voiceIdentifier = settings.speechVoiceIdentifier.isEmpty ? nil : settings.speechVoiceIdentifier
        speech.rate = settings.speechRate
        if settings.speechEnabled { speech.warmUp() }
    }

    private func speakFrontIfNeeded() {
        guard settings.speechEnabled, !drawingSession.isAnswerVisible else { return }
        switch practiceMode {
        case .kanji: if let card = session.currentKanjiCard { speech.speak(card.kanji) }
        case .kana: if let card = session.currentKanaCard { speech.speak(card.character) }
        case .words: if let card = session.currentWordCard { speech.speak(card.word) }
        case .anki: break
        }
    }
}
