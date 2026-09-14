import SwiftUI

private let canonicalSize: CGFloat = 109

private enum AppPalette {
    static let background = Color(red: 0.95, green: 0.94, blue: 0.90)
    static let surface = Color.white
    static let text = Color(red: 0.12, green: 0.11, blue: 0.09)
    static let secondaryText = Color(red: 0.42, green: 0.38, blue: 0.32)
    static let mutedText = Color(red: 0.68, green: 0.64, blue: 0.56)
    static let border = Color(red: 0.68, green: 0.64, blue: 0.56)
    static let ink = Color(red: 0.12, green: 0.16, blue: 0.17)
    static let accent = Color(red: 0.14, green: 0.36, blue: 0.39)
    static let correction = Color(red: 0.74, green: 0.12, blue: 0.14)
    static let warning = Color(red: 0.78, green: 0.58, blue: 0.10)
    static let expectedCorrection = Color(red: 1.00, green: 0.35, blue: 0.32)
    static let expectedWarning = Color(red: 0.96, green: 0.74, blue: 0.22)
    static let expectedCorrect = Color(red: 0.50, green: 0.52, blue: 0.56)
    static let success = Color(red: 0.18, green: 0.52, blue: 0.24)
}

private enum FrontFieldKind: String, CaseIterable, Identifiable {
    case readings
    case meanings
    case character

    var id: String { rawValue }

    var title: String {
        switch self {
        case .readings:
            return "Чтения"
        case .meanings:
            return "Значения"
        case .character:
            return "Знак"
        }
    }
}

struct ContentView: View {
    @State private var practiceMode: PracticeMode = .kanji
    @State private var cards: [KanjiCard] = []
    @State private var wordCards: [WordStudyCard] = []
    @State private var kanaCards: [KanaStudyCard] = []
    @State private var selectedDeck: KanjiDeck = .jlpt5
    @State private var previewDeck: KanjiDeck?
    @State private var previewCards: [KanjiCard] = []
    @State private var previewExpectedCount: Int?
    @State private var selectedPreviewCard: KanjiCard?
    @State private var isPreviewDetailPresented = false
    @State private var previewSwipeDirection = 0
    @State private var deckPreviewTask: Task<Void, Never>?
    @State private var previewTranslationTask: Task<Void, Never>?
    @State private var isLoadingDeck = false
    @State private var isPreparingCard = false
    @State private var hasStartedTraining = false
    @State private var reviewStore = KanjiReviewStore(records: [:])

    @State private var currentIndex = 0
    @State private var currentWordKanjiIndex = 0
    @State private var completedWordDrawings: [[[CGPoint]]] = []
    @State private var wordFeedbackByKanji: [[StrokeFeedback]] = []
    @State private var sessionTotalCards = 0
    @State private var sessionCompletedCards = 0
    @State private var drawnStrokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var feedback: [StrokeFeedback] = []
    @State private var guidedStrokeLimit = 1
    @State private var showsFeedbackInfo = false
    @State private var isAnswerVisible = false
    @State private var scrollToTopToken = 0
    @State private var pretranslationTask: Task<Void, Never>?
    @State private var selectedWordDeck: WordFrequencyDeck = .top1000
    @State private var showsPromptCharacters = false
    @State private var showsPromptReading = true
    @State private var showsPromptMeaning = false
    @State private var frontFieldOrder: [FrontFieldKind] = [.readings, .meanings, .character]
    @State private var draggedFrontField: FrontFieldKind?
    @State private var frontFieldDragOffset: CGFloat = 0
    @State private var frontFieldDragStartIndex: Int?
    @State private var isGuidedSingleKanjiPractice = false

    var body: some View {
        NavigationStack {
            Group {
                if hasStartedTraining {
                    activeTrainingView()
                } else if let previewDeck {
                    deckPreviewView(for: previewDeck)
                } else {
                    startView()
                }
            }
            .navigationTitle(hasStartedTraining ? "Kanji Trainer" : previewDeck == nil ? "Набор карточек" : "Колода")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppPalette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .task {
                await loadReviewMemory()
            }
        }
    }

    private func startView() -> some View {
        ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("Выбери набор")
                    .font(.largeTitle.weight(.bold))

                Picker("Режим", selection: $practiceMode) {
                    ForEach(PracticeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack(alignment: .top, spacing: 12) {
                    Text(startSubtitle)
                        .foregroundStyle(AppPalette.secondaryText)

                    Spacer()

                    Button {
                        clearDeckCache()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(AppPalette.correction)
                    .disabled(isLoadingDeck)
                }

                frontSettingsView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if practiceMode == .hiragana || practiceMode == .katakana {
                            kanaStartButton()
                        } else if practiceMode == .words {
                            ForEach(WordFrequencyDeck.groups, id: \.title) { group in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(group.title)
                                        .font(.headline)
                                        .foregroundStyle(AppPalette.secondaryText)

                                    VStack(spacing: 10) {
                                        ForEach(group.decks) { deck in
                                            wordDeckButton(for: deck)
                                        }
                                    }
                                }
                            }
                        } else {
                            ForEach(KanjiDeck.groups, id: \.title) { group in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(group.title)
                                        .font(.headline)
                                        .foregroundStyle(AppPalette.secondaryText)

                                    VStack(spacing: 10) {
                                        ForEach(group.decks) { deck in
                                            deckButton(for: deck)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if isLoadingDeck {
                    ProgressView("Скачиваю и кэширую \(selectedDeck.title)")
                        .foregroundStyle(AppPalette.secondaryText)
                        .tint(AppPalette.accent)
                }

                Spacer()
            }
            .padding(20)
            .foregroundStyle(AppPalette.text)
        }
    }

    private func frontSettingsView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Лицевая сторона")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.secondaryText)
                .textCase(.uppercase)

            VStack(spacing: 8) {
                ForEach(frontFieldOrder) { field in
                    frontSettingRow(for: field)
                        .offset(y: draggedFrontField == field ? frontFieldDragOffset : 0)
                        .zIndex(draggedFrontField == field ? 1 : 0)
                        .simultaneousGesture(frontFieldDragGesture(for: field))
                }
            }
        }
        .padding(12)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppPalette.border.opacity(0.65), lineWidth: 1)
        )
        .disabled(isLoadingDeck)
    }

    private func frontSettingRow(for field: FrontFieldKind) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(AppPalette.mutedText)
                .frame(width: 18)

            Toggle(field.title, isOn: binding(for: field))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppPalette.background.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(draggedFrontField == field ? AppPalette.accent.opacity(0.55) : Color.clear, lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .scaleEffect(draggedFrontField == field ? 1.006 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.95), value: frontFieldOrder)
        .animation(.easeInOut(duration: 0.12), value: draggedFrontField)
    }

    private func frontFieldDragGesture(for field: FrontFieldKind) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if draggedFrontField == nil {
                    draggedFrontField = field
                    frontFieldDragStartIndex = frontFieldOrder.firstIndex(of: field)
                }

                guard draggedFrontField == field else {
                    return
                }

                frontFieldDragOffset = clampedFrontFieldDragOffset(for: field, translation: value.translation.height)
            }
            .onEnded { value in
                moveFrontField(field, translation: value.translation.height)
                withAnimation(.easeOut(duration: 0.14)) {
                    frontFieldDragOffset = 0
                    frontFieldDragStartIndex = nil
                    draggedFrontField = nil
                }
            }
    }

    private func clampedFrontFieldDragOffset(for field: FrontFieldKind, translation: CGFloat) -> CGFloat {
        let rowStride: CGFloat = 54
        guard let startIndex = frontFieldDragStartIndex else {
            return translation
        }

        let minOffset = CGFloat(-startIndex) * rowStride
        let maxOffset = CGFloat(frontFieldOrder.count - 1 - startIndex) * rowStride
        return min(max(translation, minOffset), maxOffset)
    }

    private func moveFrontField(_ field: FrontFieldKind, translation: CGFloat) {
        let rowStride: CGFloat = 54
        guard let startIndex = frontFieldDragStartIndex,
              let currentIndex = frontFieldOrder.firstIndex(of: field) else {
            return
        }

        let steps = Int((translation / rowStride).rounded())
        let targetIndex = min(max(startIndex + steps, 0), frontFieldOrder.count - 1)
        guard targetIndex != currentIndex else {
            return
        }

        withAnimation(.easeOut(duration: 0.16)) {
            frontFieldOrder.move(
                fromOffsets: IndexSet(integer: currentIndex),
                toOffset: targetIndex > currentIndex ? targetIndex + 1 : targetIndex
            )
        }
    }

    private func binding(for field: FrontFieldKind) -> Binding<Bool> {
        switch field {
        case .readings:
            return $showsPromptReading
        case .meanings:
            return $showsPromptMeaning
        case .character:
            return $showsPromptCharacters
        }
    }

    private var trainingTitle: String {
        switch practiceMode {
        case .kanji:
            return selectedDeck.title
        case .words:
            return "Слова: \(selectedWordDeck.title)"
        case .hiragana, .katakana:
            return practiceMode.title
        }
    }

    private var startSubtitle: String {
        switch practiceMode {
        case .kanji:
            return "Первый запуск скачает весь пакет из kanjiapi.dev и сохранит его в кэш."
        case .words:
            return "Слова берутся локально из полного словаря и группируются диапазонами по частоте."
        case .hiragana:
            return "Тренировка базовой хираганы без интернета."
        case .katakana:
            return "Тренировка базовой катаканы без интернета."
        }
    }

    private func loadReviewMemory() async {
        await Task.yield()
        reviewStore = KanjiReviewStore.load()
    }

    private func kanaStartButton() -> some View {
        Button {
            startKanaTraining()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(practiceMode.title)
                        .font(.headline)
                    Text("\(practiceMode == .hiragana ? KanaStudyCard.hiragana.count : KanaStudyCard.katakana.count) карточек")
                        .font(.caption)
                        .foregroundStyle(AppPalette.secondaryText)
                }

                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.border.opacity(0.65), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoadingDeck)
    }

    private func deckButton(for deck: KanjiDeck) -> some View {
        Button {
            selectedDeck = deck
            openDeckPreview(deck)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(deck.title)
                        .font(.headline)
                    Text(deck.endpointPath)
                        .font(.caption)
                        .foregroundStyle(AppPalette.secondaryText)
                }

                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.border.opacity(0.65), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoadingDeck)
    }

    private func wordDeckButton(for deck: WordFrequencyDeck) -> some View {
        Button {
            selectedWordDeck = deck
            Task {
                await loadSelectedWordDeck()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(deck.title)
                        .font(.headline)
                    Text(deck.subtitle)
                        .font(.caption)
                        .foregroundStyle(AppPalette.secondaryText)
                }

                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.border.opacity(0.65), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoadingDeck)
    }

    private func deckPreviewView(for deck: KanjiDeck) -> some View {
        ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Button("", systemImage: "chevron.left") {
                        closeDeckPreview()
                    }
                    .buttonStyle(.bordered)
                    .tint(AppPalette.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(deck.title)
                            .font(.title2.weight(.bold))
                        Text(deckPreviewStatus)
                            .font(.caption)
                            .foregroundStyle(AppPalette.secondaryText)
                    }

                    Spacer()
                }

                Button {
                    startRandomTrainingFromPreview()
                } label: {
                    HStack {
                        Image(systemName: "shuffle")
                        Text("Начать тренировку")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(previewCards.count)")
                            .foregroundStyle(AppPalette.secondaryText)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.accent)
                .disabled(previewCards.isEmpty)

                ScrollView(.vertical) {
                    LazyVGrid(columns: kanjiPreviewColumns, spacing: 10) {
                        ForEach(previewCards) { card in
                            kanjiPreviewTile(for: card)
                        }
                    }
                    .padding(.bottom, 20)
                }

                if isLoadingDeck {
                    ProgressView("Загружаю карточки")
                        .foregroundStyle(AppPalette.secondaryText)
                        .tint(AppPalette.accent)
                }
            }
            .padding(20)
            .foregroundStyle(AppPalette.text)
        }
        .sheet(isPresented: $isPreviewDetailPresented) {
            selectedPreviewCard = nil
            previewSwipeDirection = 0
        } content: {
            if let selectedPreviewCard {
                kanjiPreviewDetail(for: selectedPreviewCard)
            }
        }
    }

    private var kanjiPreviewColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
    }

    private var deckPreviewStatus: String {
        if let previewExpectedCount {
            return "\(previewCards.count) / \(previewExpectedCount) загружено"
        }

        return "\(previewCards.count) загружено"
    }

    private func kanjiPreviewTile(for card: KanjiCard) -> some View {
        Button {
            selectedPreviewCard = card
            previewSwipeDirection = 0
            isPreviewDetailPresented = true
        } label: {
            VStack(spacing: 6) {
                Text(card.kanji)
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .frame(maxWidth: .infinity)

                Text(card.meanings.prefix(2).joined(separator: ", "))
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppPalette.secondaryText)
                    .frame(height: 28, alignment: .top)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 86)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.border.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func kanjiPreviewDetail(for card: KanjiCard) -> some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    cardBack(for: card)
                        .padding(18)
                        .background(AppPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppPalette.border.opacity(0.65), lineWidth: 1)
                        )

                    Button {
                        selectedPreviewCard = nil
                        isPreviewDetailPresented = false
                        startTraining(with: [card], guided: true)
                    } label: {
                        HStack {
                            Image(systemName: "pencil.and.scribble")
                            Text("Тренировать этот кандзи")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.accent)
                }
                .padding(20)
            }
            .background(AppPalette.background)
            .id(card.kanji)
            .transition(previewDetailTransition)
            .highPriorityGesture(previewCardSwipeGesture(for: card))
        }
    }

    private var previewDetailTransition: AnyTransition {
        if previewSwipeDirection < 0 {
            return .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
        }

        if previewSwipeDirection > 0 {
            return .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
        }

        return .opacity
    }

    private func previewCardSwipeGesture(for card: KanjiCard) -> some Gesture {
        DragGesture(minimumDistance: 35)
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height
                guard abs(width) > abs(height) * 1.25, abs(width) > 55 else {
                    return
                }

                guard let index = previewCards.firstIndex(where: { $0.kanji == card.kanji }) else {
                    return
                }

                if width < 0, let nextCard = previewCards[safe: index + 1] {
                    previewSwipeDirection = -1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedPreviewCard = nextCard
                    }
                } else if width > 0, let previousCard = previewCards[safe: index - 1] {
                    previewSwipeDirection = 1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedPreviewCard = previousCard
                    }
                }
            }
    }

    @ViewBuilder
    private func activeTrainingView() -> some View {
        switch practiceMode {
        case .kanji:
            if let card = cards[safe: currentIndex] {
                trainingView(for: card)
            } else {
                startView()
            }
        case .words:
            if let wordCard = wordCards[safe: currentIndex] {
                wordTrainingView(for: wordCard)
            } else {
                startView()
            }
        case .hiragana, .katakana:
            if let kanaCard = kanaCards[safe: currentIndex] {
                kanaTrainingView(for: kanaCard)
            } else {
                startView()
            }
        }
    }

    private func trainingView(for card: KanjiCard) -> some View {
        GeometryReader { proxy in
            let panelHeight = drawingPanelHeight(for: proxy.size)

            ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollViewReader { scrollProxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        Color.clear
                            .frame(height: 0)
                            .id("trainingTop")

                        headerControls()
                        studyCard(for: card)
                    }
                    .padding(20)
                    .padding(.bottom, 12)
                    .foregroundStyle(AppPalette.text)
                }
                .background(AppPalette.background)
                .simultaneousGesture(cardSwipeGesture())
                .onChange(of: scrollToTopToken) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                            scrollProxy.scrollTo("trainingTop", anchor: .top)
                    }
                }
            }

                drawingPanel(for: card, panelHeight: panelHeight)
            }
        }
        }
    }

    private func wordTrainingView(for wordCard: WordStudyCard) -> some View {
        let currentKanji = currentWordKanjiCard(for: wordCard)

        return GeometryReader { proxy in
            let panelHeight = drawingPanelHeight(for: proxy.size)

            ZStack {
            AppPalette.background
                .ignoresSafeArea()

                VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    headerControls()
                    wordStudyCard(for: wordCard)
                    completedWordStrip(for: wordCard)
                }
                .padding(20)
                .padding(.bottom, 12)
                .foregroundStyle(AppPalette.text)
            }
            .simultaneousGesture(cardSwipeGesture())

                    if let currentKanji {
                        wordDrawingPanel(for: wordCard, currentKanji: currentKanji, panelHeight: panelHeight)
                    }
                }
        }
        }
    }

    private func kanaTrainingView(for kanaCard: KanaStudyCard) -> some View {
        GeometryReader { proxy in
            let panelHeight = drawingPanelHeight(for: proxy.size)

            ZStack {
            AppPalette.background
                .ignoresSafeArea()

                VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    headerControls()
                    kanaStudyCard(for: kanaCard)
                }
                .padding(20)
                .padding(.bottom, 12)
                .foregroundStyle(AppPalette.text)
            }
            .simultaneousGesture(cardSwipeGesture())

                    kanaDrawingPanel(for: kanaCard, panelHeight: panelHeight)
                }
        }
        }
    }

    private func wordStudyCard(for wordCard: WordStudyCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Слово")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.secondaryText)
                .textCase(.uppercase)

            wordFrontFields(for: wordCard)

            if !isAnswerVisible && !showsPromptCharacters && !showsPromptReading && !showsPromptMeaning {
                Text("Нарисуй символы слова по памяти.")
                    .font(.title2.weight(.semibold))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppPalette.border.opacity(0.65), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .highPriorityGesture(cardSwipeGesture())
    }

    @ViewBuilder
    private func wordFrontFields(for wordCard: WordStudyCard) -> some View {
        ForEach(frontFieldOrder) { field in
            switch field {
            case .readings:
                wordReadingField(for: wordCard)
            case .meanings:
                wordMeaningField(for: wordCard)
            case .character:
                wordCharacterField(for: wordCard)
            }
        }
    }

    @ViewBuilder
    private func wordCharacterField(for wordCard: WordStudyCard) -> some View {
        if isAnswerVisible || showsPromptCharacters {
            detailBlock("Слово") {
                Text(wordCard.word)
                    .font(.system(size: 42, weight: .regular, design: .serif))
            }
        }
    }

    @ViewBuilder
    private func wordReadingField(for wordCard: WordStudyCard) -> some View {
        if isAnswerVisible || showsPromptReading {
            detailBlock("Чтение") {
                Text(wordCard.reading)
            }
        }
    }

    @ViewBuilder
    private func wordMeaningField(for wordCard: WordStudyCard) -> some View {
        if isAnswerVisible || showsPromptMeaning {
            detailBlock("Значения") {
                Text(wordCard.meaning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func kanaStudyCard(for kanaCard: KanaStudyCard) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(kanaCard.reading)
                .font(.largeTitle.weight(.bold))

            Text(isAnswerVisible ? kanaCard.character : "Нарисуй знак каны по чтению")
                .font(.system(size: isAnswerVisible ? 92 : 24, weight: .regular, design: .serif))
                .foregroundStyle(isAnswerVisible ? AppPalette.text : AppPalette.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 140)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppPalette.border.opacity(0.65), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .highPriorityGesture(cardSwipeGesture())
    }

    private func completedWordStrip(for wordCard: WordStudyCard) -> some View {
        HStack(spacing: 8) {
            ForEach(wordCard.kanjiCards.indices, id: \.self) { index in
                let isSelected = index == currentWordKanjiIndex
                ZStack {
                    if isSelected && !drawnStrokes.isEmpty {
                        UserStrokePreview(strokes: drawnStrokes)
                    } else if index < completedWordDrawings.count {
                        UserStrokePreview(strokes: completedWordDrawings[index])
                    } else if isAnswerVisible || showsPromptCharacters {
                        Text(wordCard.kanjiCards[index].kanji)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(isAnswerVisible ? AppPalette.text : AppPalette.secondaryText)
                    } else {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(index == currentWordKanjiIndex ? AppPalette.accent : AppPalette.mutedText)
                    }
                }
                .frame(width: 34, height: 34)
                .background(AppPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? AppPalette.accent : AppPalette.border.opacity(0.45), lineWidth: isSelected ? 2 : 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectWordKanji(at: index, in: wordCard)
                }
            }
        }
    }

    private func currentWordKanjiCard(for wordCard: WordStudyCard) -> KanjiCard? {
        wordCard.kanjiCards[safe: currentWordKanjiIndex]
    }

    private func cardSwipeGesture() -> some Gesture {
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

    private func headerControls() -> some View {
        HStack(spacing: 12) {
            Button("", systemImage: "square.grid.2x2") {
                hasStartedTraining = false
            }

            Text(trainingTitle)
                .font(.headline)

            Spacer()

            Text("\(sessionCompletedCards) / \(sessionTotalCards)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppPalette.secondaryText)
                .frame(minWidth: 56)
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.accent)
    }

    private func studyCard(for card: KanjiCard) -> some View {
        ZStack {
            cardFront(for: card)
                .opacity(isAnswerVisible ? 0 : 1)
                .rotation3DEffect(.degrees(isAnswerVisible ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            cardBack(for: card)
                .opacity(isAnswerVisible ? 1 : 0)
                .rotation3DEffect(.degrees(isAnswerVisible ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppPalette.border.opacity(0.65), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .highPriorityGesture(cardSwipeGesture())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.24)) {
                isAnswerVisible.toggle()
            }
        }
    }

    private func cardFront(for card: KanjiCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Задание")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.secondaryText)
                .textCase(.uppercase)

            frontFields(for: card)

            if !showsPromptCharacters && !showsPromptReading && !showsPromptMeaning {
                Text("Нарисуй кандзи по памяти.")
                    .font(.title2.weight(.semibold))
            }

            Spacer(minLength: 16)

            Text("Проверка покажет оригинал и сравнение штрихов.")
                .foregroundStyle(AppPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func frontFields(for card: KanjiCard) -> some View {
        ForEach(frontFieldOrder) { field in
            switch field {
            case .readings:
                frontReadings(for: card)
            case .meanings:
                frontMeanings(for: card)
            case .character:
                frontCharacter(for: card)
            }
        }
    }

    @ViewBuilder
    private func frontCharacter(for card: KanjiCard) -> some View {
        if showsPromptCharacters {
            detailBlock("Кандзи") {
                Text(card.kanji)
                    .font(.system(size: 58, weight: .regular, design: .serif))
            }
        }
    }

    @ViewBuilder
    private func frontReadings(for card: KanjiCard) -> some View {
        if showsPromptReading {
            detailBlock("Онъёми") {
                Text(readingsText(card.onyomi))
            }

            detailBlock("Кунъёми") {
                Text(kunyomiText(for: card.kunyomi))
            }
        }
    }

    @ViewBuilder
    private func frontMeanings(for card: KanjiCard) -> some View {
        if showsPromptMeaning {
            detailBlock("Значения") {
                Text(card.meanings.joined(separator: ", "))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func cardBack(for card: KanjiCard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 18) {
                    Text(card.kanji)
                        .font(.system(size: 82, weight: .regular, design: .serif))
                        .frame(width: 112, height: 112)
                        .background(AppPalette.surface)
                        .border(AppPalette.border.opacity(0.65))

                    VStack(alignment: .leading, spacing: 8) {
                        detailBlock("Кандзи") {
                            Text(card.kanji)
                                .font(.title2.weight(.bold))
                        }

                        detailBlock("Онъёми") {
                            Text(readingsText(card.onyomi))
                        }

                        detailBlock("Кунъёми") {
                            Text(kunyomiText(for: card.kunyomi))
                        }

                        detailBlock("Порядок черт") {
                            StrokeStepStrip(strokes: card.strokes)
                        }

                        detailBlock("Значения") {
                            Text(card.meanings.joined(separator: ", "))
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }

                if !card.examples.isEmpty {
                    section("Примеры") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(card.examples) { example in
                                Text("\(example.word) - \(example.reading) — \(example.meaning)")
                            }
                        }
                    }
                }

            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func detailBlock<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.secondaryText)
            content()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func readingsText(_ readings: [String]) -> String {
        readings.isEmpty ? "-" : readings.joined(separator: ", ")
    }

    private func kunyomiText(for readings: [String]) -> AttributedString {
        guard !readings.isEmpty else {
            var empty = AttributedString("-")
            empty.foregroundColor = AppPalette.secondaryText
            return empty
        }

        var result = AttributedString()

        for (index, reading) in readings.enumerated() {
            if index > 0 {
                var separator = AttributedString(", ")
                separator.foregroundColor = AppPalette.text
                result += separator
            }

            let parts = reading.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            var kanjiReading = AttributedString(String(parts.first ?? ""))
            kanjiReading.foregroundColor = AppPalette.text
            result += kanjiReading

            if parts.count > 1 {
                var okurigana = AttributedString(String(parts[1]))
                okurigana.foregroundColor = AppPalette.mutedText
                result += okurigana
            }
        }

        return result
    }

    private func reviewButton(_ title: String, rating: ReviewRating, card: KanjiCard, color: Color) -> some View {
        Button {
            applyReview(rating, to: card)
        } label: {
            Text(title)
                .font(.title3.weight(.bold))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .disabled(isPreparingCard)
    }

    private func feedbackInfoButton(items: [StrokeFeedback]) -> some View {
        Button {
            showsFeedbackInfo = true
        } label: {
            Image(systemName: "info.circle")
        }
        .popover(isPresented: $showsFeedbackInfo, arrowEdge: .bottom) {
            feedbackInfoPopover(items: items)
                .presentationCompactAdaptation(.popover)
        }
    }

    private func feedbackInfoPopover(items: [StrokeFeedback]) -> some View {
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
    }

    private func drawingPanelHeight(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.36, 250), 300)
    }

    private func drawingBoardSide(for panelHeight: CGFloat) -> CGFloat {
        min(max(panelHeight - 88, 160), 205)
    }

    private func drawingPanel(for card: KanjiCard, panelHeight: CGFloat) -> some View {
        let boardSide = drawingBoardSide(for: panelHeight)

        return VStack(spacing: 8) {
            ZStack {
                DrawingBoard(
                    drawnStrokes: $drawnStrokes,
                    currentStroke: $currentStroke,
                    expectedStrokes: expectedStrokesForCurrentKanji(card),
                    feedback: feedback,
                    onStrokeFinished: {
                        handleKanjiStrokeFinished(card)
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
                        .disabled(drawnStrokes.isEmpty && currentStroke.isEmpty)

                        Spacer()

                        feedbackInfoButton(items: feedback)
                            .disabled(feedback.isEmpty)
                            .tint(feedback.isEmpty ? AppPalette.mutedText : AppPalette.accent)
                    }

                    Spacer()
                }

                HStack {
                    Button {
                        undoCurrentStroke(expected: card)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(drawnStrokes.isEmpty)

                    Spacer()

                Button {
                    advanceGuidedKanjiStrokeOrFinish(card)
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
                    undoCurrentStroke(expected: card)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(drawnStrokes.isEmpty)

                Spacer(minLength: 12)

                HStack(spacing: 10) {
                    reviewButton("-", rating: .again, card: card, color: feedback.isEmpty ? AppPalette.mutedText : AppPalette.correction)
                    reviewButton("~", rating: .hard, card: card, color: feedback.isEmpty ? AppPalette.mutedText : AppPalette.warning)
                    reviewButton("+", rating: .good, card: card, color: feedback.isEmpty ? AppPalette.mutedText : AppPalette.success)
                }
                .disabled(feedback.isEmpty)

                Spacer(minLength: 12)

                Button {
                    moveToNextCard()
                } label: {
                    if isPreparingCard {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "chevron.right")
                    }
                }
                .disabled(currentIndex >= cards.count - 1 || isPreparingCard)
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

    private func wordDrawingPanel(for wordCard: WordStudyCard, currentKanji: KanjiCard, panelHeight: CGFloat) -> some View {
        let boardSide = drawingBoardSide(for: panelHeight)

        return VStack(spacing: 8) {
            ZStack {
                DrawingBoard(
                    drawnStrokes: $drawnStrokes,
                    currentStroke: $currentStroke,
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
                        .disabled(drawnStrokes.isEmpty && currentStroke.isEmpty)

                        Spacer()

                        feedbackInfoButton(items: feedback)
                            .disabled(feedback.isEmpty)
                            .tint(feedback.isEmpty ? AppPalette.mutedText : AppPalette.accent)
                    }

                    Spacer()
                }

                HStack {
                    Button {
                        undoCurrentWordStroke(wordCard, currentKanji: currentKanji)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(drawnStrokes.isEmpty)

                    Spacer()

                    Button {
                        advanceWordKanjiOrCheck(wordCard)
                    } label: {
                    Image(systemName: currentWordKanjiIndex < wordCard.kanjiCards.count - 1 ? "arrow.right.circle.fill" : "checkmark.circle.fill")
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
                    undoCurrentWordStroke(wordCard, currentKanji: currentKanji)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(drawnStrokes.isEmpty)

                Spacer(minLength: 12)

                HStack(spacing: 10) {
                    Button("-") { applyWordReview(.again) }.buttonStyle(.borderedProminent).tint(feedback.isEmpty ? AppPalette.mutedText : AppPalette.correction)
                    Button("~") { applyWordReview(.hard) }.buttonStyle(.borderedProminent).tint(feedback.isEmpty ? AppPalette.mutedText : AppPalette.warning)
                    Button("+") { applyWordReview(.good) }.buttonStyle(.borderedProminent).tint(feedback.isEmpty ? AppPalette.mutedText : AppPalette.success)
                }
                .disabled(feedback.isEmpty)

                Spacer(minLength: 12)

                Button {
                    moveToNextCard()
                } label: {
                    if isPreparingCard {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "chevron.right")
                    }
                }
                .disabled(currentIndex >= wordCards.count - 1 || isPreparingCard)
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

    private func kanaDrawingPanel(for kanaCard: KanaStudyCard, panelHeight: CGFloat) -> some View {
        let boardSide = drawingBoardSide(for: panelHeight)

        return VStack(spacing: 8) {
            ZStack {
                DrawingBoard(
                    drawnStrokes: $drawnStrokes,
                    currentStroke: $currentStroke,
                    expectedStrokes: [],
                    feedback: [],
                    onStrokeFinished: nil
                )
                .frame(width: boardSide, height: boardSide)

                VStack {
                    HStack {
                        Button {
                            drawnStrokes.removeAll()
                            currentStroke.removeAll()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(drawnStrokes.isEmpty && currentStroke.isEmpty)

                        Spacer()

                        Image(systemName: "info.circle")
                            .foregroundStyle(AppPalette.mutedText)
                    }

                    Spacer()
                }

                HStack {
                    Button {
                        _ = drawnStrokes.popLast()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(drawnStrokes.isEmpty)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            isAnswerVisible = true
                        }
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
                Button { _ = drawnStrokes.popLast() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(drawnStrokes.isEmpty)

                Spacer(minLength: 12)

                HStack(spacing: 10) {
                    Button("-") { applyKanaReview(.again) }.buttonStyle(.borderedProminent).tint(isAnswerVisible ? AppPalette.correction : AppPalette.mutedText)
                    Button("~") { applyKanaReview(.hard) }.buttonStyle(.borderedProminent).tint(isAnswerVisible ? AppPalette.warning : AppPalette.mutedText)
                    Button("+") { applyKanaReview(.good) }.buttonStyle(.borderedProminent).tint(isAnswerVisible ? AppPalette.success : AppPalette.mutedText)
                }
                .disabled(!isAnswerVisible)

                Spacer(minLength: 12)

                Button { moveToNextCard() } label: { Image(systemName: "chevron.right") }
                    .disabled(currentIndex >= kanaCards.count - 1 || isPreparingCard)
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

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func clearDeckCache() {
        pretranslationTask?.cancel()
        pretranslationTask = nil
        deckPreviewTask?.cancel()
        deckPreviewTask = nil
        previewTranslationTask?.cancel()
        previewTranslationTask = nil
        KanjiDataLoader.clearCache()
        cards.removeAll()
        wordCards.removeAll()
        kanaCards.removeAll()
        previewCards.removeAll()
        previewExpectedCount = nil
        previewDeck = nil
        currentIndex = 0
        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
        sessionTotalCards = 0
        sessionCompletedCards = 0
        resetCurrentAnswer()
    }

    private func openDeckPreview(_ deck: KanjiDeck) {
        deckPreviewTask?.cancel()
        previewTranslationTask?.cancel()
        previewDeck = deck
        previewCards.removeAll()
        previewExpectedCount = nil
        selectedPreviewCard = nil
        isLoadingDeck = true

        deckPreviewTask = Task {
            await KanjiDataLoader.loadCardsProgressively(deck: deck) { loadedCards, expectedCount in
                guard previewDeck == deck else {
                    return
                }

                previewCards = reviewStore.orderedCards(loadedCards)
                previewExpectedCount = expectedCount
                isLoadingDeck = previewExpectedCount.map { previewCards.count < $0 } ?? false
                schedulePreviewTranslations(for: deck)
            }

            if previewDeck == deck {
                isLoadingDeck = false
            }
        }
    }

    private func closeDeckPreview() {
        deckPreviewTask?.cancel()
        deckPreviewTask = nil
        previewTranslationTask?.cancel()
        previewTranslationTask = nil
        previewDeck = nil
        previewCards.removeAll()
        previewExpectedCount = nil
        selectedPreviewCard = nil
        isLoadingDeck = false
    }

    private func startRandomTrainingFromPreview() {
        startTraining(with: previewCards.shuffled(), guided: false)
    }

    private func startTraining(with trainingCards: [KanjiCard], guided: Bool) {
        guard !trainingCards.isEmpty else {
            return
        }

        deckPreviewTask?.cancel()
        pretranslationTask?.cancel()
        pretranslationTask = nil
        cards = trainingCards
        wordCards.removeAll()
        kanaCards.removeAll()
        currentIndex = 0
        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
        sessionTotalCards = cards.count
        sessionCompletedCards = 0
        isGuidedSingleKanjiPractice = guided
        hasStartedTraining = true
        resetCurrentAnswer()
        scheduleNextCardTranslation()
    }

    private func schedulePreviewTranslations(for deck: KanjiDeck) {
        let pendingCards = previewCards.filter { $0.translationState != "ru-system" }
        guard !pendingCards.isEmpty else {
            return
        }

        previewTranslationTask?.cancel()
        previewTranslationTask = Task {
            for card in pendingCards {
                guard !Task.isCancelled else {
                    return
                }

                let translatedCard = await KanjiDataLoader.translateCardIfNeeded(card, deck: deck)

                await MainActor.run {
                    guard previewDeck == deck else {
                        return
                    }

                    replaceCard(translatedCard)
                }
            }
        }
    }

    private func replaceCard(_ card: KanjiCard) {
        for index in previewCards.indices where previewCards[index].kanji == card.kanji {
            previewCards[index] = card
        }

        for index in cards.indices where cards[index].kanji == card.kanji {
            cards[index] = card
        }
    }

    private func loadSelectedWordDeck() async {
        guard !isLoadingDeck else {
            return
        }

        pretranslationTask?.cancel()
        pretranslationTask = nil
        isLoadingDeck = true
        cards.removeAll()
        kanaCards.removeAll()

        await Task.yield()

        let deck = selectedWordDeck
        let masterCards = KanjiDataLoader.loadBundledMasterCards()
        let sourceCards = masterCards.isEmpty ? KanjiDataLoader.loadLocalCards() : masterCards
        let builtWords = WordStudyCard.build(from: sourceCards)
        let preparedWords = deck.cards(from: builtWords)

        guard selectedWordDeck == deck else {
            isLoadingDeck = false
            return
        }

        wordCards = preparedWords
        currentIndex = 0
        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
        sessionTotalCards = wordCards.count
        sessionCompletedCards = 0
        isGuidedSingleKanjiPractice = false
        isLoadingDeck = false
        hasStartedTraining = !wordCards.isEmpty
        resetCurrentAnswer()
    }

    private func startKanaTraining() {
        pretranslationTask?.cancel()
        pretranslationTask = nil
        cards.removeAll()
        wordCards.removeAll()
        kanaCards = practiceMode == .hiragana ? KanaStudyCard.hiragana : KanaStudyCard.katakana
        currentIndex = 0
        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
        sessionTotalCards = kanaCards.count
        sessionCompletedCards = 0
        isGuidedSingleKanjiPractice = false
        hasStartedTraining = true
        resetCurrentAnswer()
    }

    private func loadSelectedDeck() async {
        guard !isLoadingDeck else {
            return
        }

        pretranslationTask?.cancel()
        pretranslationTask = nil
        isLoadingDeck = true
        let loadedCards = await KanjiDataLoader.loadCards(deck: selectedDeck)

        guard !loadedCards.isEmpty else {
            isLoadingDeck = false
            return
        }

        var orderedCards = reviewStore.orderedCards(loadedCards)
        if let firstCard = orderedCards.first {
            orderedCards[0] = await KanjiDataLoader.translateCardIfNeeded(firstCard, deck: selectedDeck)
        }

        cards = orderedCards
        wordCards = WordStudyCard.build(from: orderedCards)
        currentIndex = 0
        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
        sessionTotalCards = practiceMode == .words ? wordCards.count : orderedCards.count
        sessionCompletedCards = 0
        isGuidedSingleKanjiPractice = false
        isLoadingDeck = false
        hasStartedTraining = true
        resetCurrentAnswer()
        scheduleNextCardTranslation()
    }

    private func advanceWordKanjiOrCheck(_ wordCard: WordStudyCard) {
        guard currentWordKanjiIndex < wordCard.kanjiCards.count else {
            return
        }

        saveCurrentWordDrawing()

        if currentWordKanjiIndex < wordCard.kanjiCards.count - 1 {
            currentWordKanjiIndex += 1
            drawnStrokes = completedWordDrawings[safe: currentWordKanjiIndex] ?? []
            guidedStrokeLimit = nextGuidedStrokeLimit(for: wordCard.kanjiCards[currentWordKanjiIndex])
            currentStroke.removeAll()
            return
        }

        wordFeedbackByKanji = evaluateWordParts(wordCard)
        feedback = flattenedWordFeedback(for: wordCard)
        withAnimation(.easeInOut(duration: 0.24)) {
            isAnswerVisible = true
        }
    }

    private func selectWordKanji(at index: Int, in wordCard: WordStudyCard) {
        guard wordCard.kanjiCards.indices.contains(index) else {
            return
        }

        if !isAnswerVisible {
            saveCurrentWordDrawing()
        }

        currentWordKanjiIndex = index
        drawnStrokes = completedWordDrawings[safe: index] ?? []
        guidedStrokeLimit = nextGuidedStrokeLimit(for: wordCard.kanjiCards[index])
        currentStroke.removeAll()
    }

    private var currentWordFeedback: [StrokeFeedback] {
        wordFeedbackByKanji[safe: currentWordKanjiIndex] ?? []
    }

    private func saveCurrentWordDrawing() {
        while completedWordDrawings.count <= currentWordKanjiIndex {
            completedWordDrawings.append([])
        }

        completedWordDrawings[currentWordKanjiIndex] = drawnStrokes
    }

    private func evaluateWordParts(_ wordCard: WordStudyCard) -> [[StrokeFeedback]] {
        wordCard.kanjiCards.indices.map { index in
            let strokes = index < completedWordDrawings.count ? completedWordDrawings[index] : []
            return StrokeEvaluator.evaluate(actual: strokes, expected: wordCard.kanjiCards[index].strokes)
        }
    }

    private func flattenedWordFeedback(for wordCard: WordStudyCard) -> [StrokeFeedback] {
        wordFeedbackByKanji.enumerated().flatMap { index, items in
            items.map { item in
                StrokeFeedback(
                    strokeIndex: nil,
                    severity: item.severity,
                    message: "\(wordCard.kanjiCards[index].kanji): \(item.message)"
                )
            }
        }
    }

    private func guidedExpectedStrokes(for card: KanjiCard) -> [KanjiStroke] {
        guard !card.strokes.isEmpty else {
            return []
        }

        return Array(card.strokes.prefix(min(guidedStrokeLimit, card.strokes.count)))
    }

    private func expectedStrokesForCurrentKanji(_ card: KanjiCard) -> [KanjiStroke] {
        guard isGuidedSingleKanjiPractice else {
            return isAnswerVisible || !feedback.isEmpty ? card.strokes : []
        }

        return guidedExpectedStrokes(for: card)
    }

    private func expectedStrokesForCurrentWordKanji(_ card: KanjiCard) -> [KanjiStroke] {
        isAnswerVisible || !currentWordFeedback.isEmpty ? card.strokes : []
    }

    private func undoCurrentStroke(expected card: KanjiCard) {
        _ = drawnStrokes.popLast()
//        feedback = StrokeEvaluator.evaluateCompletedStrokes(actual: drawnStrokes, expected: card.strokes)
//        guidedStrokeLimit = nextGuidedStrokeLimit(for: card)
    }

    private func clearCurrentDrawing(expected card: KanjiCard) {
        drawnStrokes.removeAll()
        currentStroke.removeAll()
        feedback.removeAll()
        guidedStrokeLimit = nextGuidedStrokeLimit(for: card)
        showsFeedbackInfo = false
    }

    private func undoCurrentWordStroke(_ wordCard: WordStudyCard, currentKanji: KanjiCard) {
        _ = drawnStrokes.popLast()
        let currentFeedback = StrokeEvaluator.evaluateCompletedStrokes(actual: drawnStrokes, expected: currentKanji.strokes)
        storeCurrentWordFeedback(currentFeedback, in: wordCard)
        feedback = flattenedWordFeedback(for: wordCard)
        guidedStrokeLimit = nextGuidedStrokeLimit(for: currentKanji)
    }

    private func clearCurrentWordDrawing(_ wordCard: WordStudyCard, currentKanji: KanjiCard) {
        drawnStrokes.removeAll()
        currentStroke.removeAll()
        storeCurrentWordFeedback([], in: wordCard)
        feedback = flattenedWordFeedback(for: wordCard)
        guidedStrokeLimit = nextGuidedStrokeLimit(for: currentKanji)
        showsFeedbackInfo = false
    }

    private func nextGuidedStrokeLimit(for card: KanjiCard) -> Int {
        guard !card.strokes.isEmpty else {
            return 1
        }

        return min(max(drawnStrokes.count + 1, 1), card.strokes.count)
    }

    private func handleKanjiStrokeFinished(_ card: KanjiCard) {
        guard isGuidedSingleKanjiPractice else {
            return
        }

        guard !card.strokes.isEmpty else {
            return
        }

        feedback = StrokeEvaluator.evaluateCompletedStrokes(actual: drawnStrokes, expected: card.strokes)
        let latestSeverity = feedback.last { $0.strokeIndex == drawnStrokes.count - 1 }?.severity

        if latestSeverity == .good || latestSeverity == .minor {
            advanceGuidedKanjiStrokeOrFinish(card)
        }
    }

    private func advanceGuidedKanjiStrokeOrFinish(_ card: KanjiCard) {
        guard isGuidedSingleKanjiPractice else {
            updateFeedback(for: card, reveal: true)
            return
        }

        guard !card.strokes.isEmpty else {
            updateFeedback(for: card, reveal: true)
            return
        }

        if drawnStrokes.count >= card.strokes.count {
            updateFeedback(for: card, reveal: true)
            return
        }

        guidedStrokeLimit = min(max(guidedStrokeLimit + 1, drawnStrokes.count + 1), card.strokes.count)
    }

    private func handleWordStrokeFinished(_ wordCard: WordStudyCard, currentKanji: KanjiCard) {
        guard !currentKanji.strokes.isEmpty else {
            return
        }

        let currentFeedback = StrokeEvaluator.evaluateCompletedStrokes(actual: drawnStrokes, expected: currentKanji.strokes)
        storeCurrentWordFeedback(currentFeedback, in: wordCard)
        feedback = flattenedWordFeedback(for: wordCard)

        let latestSeverity = currentFeedback.last { $0.strokeIndex == drawnStrokes.count - 1 }?.severity
        if latestSeverity == .good || latestSeverity == .minor {
            advanceGuidedWordStrokeOrStep(wordCard, currentKanji: currentKanji)
        }
    }

    private func advanceGuidedWordStrokeOrStep(_ wordCard: WordStudyCard, currentKanji: KanjiCard) {
        guard !currentKanji.strokes.isEmpty else {
            advanceWordKanjiOrCheck(wordCard)
            return
        }

        if drawnStrokes.count >= currentKanji.strokes.count {
            advanceWordKanjiOrCheck(wordCard)
            guidedStrokeLimit = nextGuidedStrokeLimit(for: currentWordKanjiCard(for: wordCard) ?? currentKanji)
            return
        }

        guidedStrokeLimit = min(max(guidedStrokeLimit + 1, drawnStrokes.count + 1), currentKanji.strokes.count)
    }

    private func storeCurrentWordFeedback(_ items: [StrokeFeedback], in wordCard: WordStudyCard) {
        while wordFeedbackByKanji.count < wordCard.kanjiCards.count {
            wordFeedbackByKanji.append([])
        }

        wordFeedbackByKanji[currentWordKanjiIndex] = items
    }

    private func applyWordReview(_ rating: ReviewRating) {
        guard wordCards.indices.contains(currentIndex), !isPreparingCard else {
            return
        }

        switch rating {
        case .again:
            moveCurrentWordLater(after: 2)
        case .hard:
            moveCurrentWordLater(after: 5)
        case .good:
            sessionCompletedCards = min(sessionCompletedCards + 1, sessionTotalCards)
            wordCards.remove(at: currentIndex)
        }

        prepareCurrentWordOrFinish()
    }

    private func moveCurrentWordLater(after offset: Int) {
        let wordCard = wordCards.remove(at: currentIndex)
        let insertIndex = min(currentIndex + offset, wordCards.count)
        wordCards.insert(wordCard, at: insertIndex)
    }

    private func prepareCurrentWordOrFinish() {
        guard !wordCards.isEmpty else {
            finishDeck()
            return
        }

        if currentIndex >= wordCards.count {
            currentIndex = wordCards.count - 1
        }

        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        resetCurrentAnswer()
        scrollToTopToken += 1
    }

    private func applyKanaReview(_ rating: ReviewRating) {
        guard kanaCards.indices.contains(currentIndex), !isPreparingCard else {
            return
        }

        switch rating {
        case .again:
            moveCurrentKanaLater(after: 2)
        case .hard:
            moveCurrentKanaLater(after: 5)
        case .good:
            sessionCompletedCards = min(sessionCompletedCards + 1, sessionTotalCards)
            kanaCards.remove(at: currentIndex)
        }

        prepareCurrentKanaOrFinish()
    }

    private func moveCurrentKanaLater(after offset: Int) {
        let kanaCard = kanaCards.remove(at: currentIndex)
        let insertIndex = min(currentIndex + offset, kanaCards.count)
        kanaCards.insert(kanaCard, at: insertIndex)
    }

    private func prepareCurrentKanaOrFinish() {
        guard !kanaCards.isEmpty else {
            finishDeck()
            return
        }

        if currentIndex >= kanaCards.count {
            currentIndex = kanaCards.count - 1
        }

        resetCurrentAnswer()
        scrollToTopToken += 1
    }

    private func applyReview(_ rating: ReviewRating, to card: KanjiCard) {
        guard !isPreparingCard else {
            return
        }

        Task { @MainActor in
            await applyReviewAndAdvance(rating, to: card)
        }
    }

    private func applyReviewAndAdvance(_ rating: ReviewRating, to card: KanjiCard) async {
        guard cards.indices.contains(currentIndex), cards[currentIndex].kanji == card.kanji else {
            return
        }

        reviewStore.apply(rating, to: card.kanji)

        switch rating {
        case .again:
            moveCurrentCardLater(after: 2)
        case .hard:
            moveCurrentCardLater(after: 5)
        case .good:
            sessionCompletedCards = min(sessionCompletedCards + 1, sessionTotalCards)
            cards.remove(at: currentIndex)
        }

        await prepareCurrentCardOrFinish()
    }

    private func moveCurrentCardLater(after offset: Int) {
        let card = cards.remove(at: currentIndex)
        let insertIndex = min(currentIndex + offset, cards.count)
        cards.insert(card, at: insertIndex)
    }

    private func prepareCurrentCardOrFinish() async {
        guard !cards.isEmpty else {
            finishDeck()
            return
        }

        if currentIndex >= cards.count {
            currentIndex = cards.count - 1
        }

        await prepareAndMoveToCard(at: currentIndex)
    }

    private func finishDeck() {
        pretranslationTask?.cancel()
        pretranslationTask = nil
        cards.removeAll()
        wordCards.removeAll()
        kanaCards.removeAll()
        currentIndex = 0
        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
        sessionTotalCards = 0
        sessionCompletedCards = 0
        isGuidedSingleKanjiPractice = false
        isPreparingCard = false
        hasStartedTraining = false
        resetCurrentAnswer()
    }

    private func moveToPreviousCard() {
        guard currentIndex > 0, !isPreparingCard else {
            return
        }

        currentIndex -= 1
        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
        resetCurrentAnswer()
        scrollToTopToken += 1
        scheduleNextCardTranslation()
    }

    private func moveToNextCard() {
        guard !isPreparingCard else {
            return
        }

        switch practiceMode {
        case .kanji:
            guard currentIndex < cards.count - 1 else {
                return
            }
            let targetIndex = currentIndex + 1
            Task { @MainActor in
                await prepareAndMoveToCard(at: targetIndex)
            }
        case .words:
            guard currentIndex < wordCards.count - 1 else {
                return
            }
            currentIndex += 1
            currentWordKanjiIndex = 0
            completedWordDrawings.removeAll()
            wordFeedbackByKanji.removeAll()
            resetCurrentAnswer()
            scrollToTopToken += 1
        case .hiragana, .katakana:
            guard currentIndex < kanaCards.count - 1 else {
                return
            }
            currentIndex += 1
            resetCurrentAnswer()
            scrollToTopToken += 1
        }
    }

    private func prepareAndMoveToCard(at targetIndex: Int) async {
        guard cards.indices.contains(targetIndex), !isPreparingCard else {
            return
        }

        pretranslationTask?.cancel()
        pretranslationTask = nil
        isPreparingCard = true

        let deck = selectedDeck
        let card = cards[targetIndex]
        let preparedCard = card.translationState == "ru-system"
            ? card
            : await KanjiDataLoader.translateCardIfNeeded(card, deck: deck)

        guard selectedDeck == deck, cards.indices.contains(targetIndex) else {
            isPreparingCard = false
            return
        }

        cards[targetIndex] = preparedCard
        currentIndex = targetIndex
        resetCurrentAnswer()
        scrollToTopToken += 1
        isPreparingCard = false
        scheduleNextCardTranslation()
    }

    private func scheduleNextCardTranslation() {
        pretranslationTask?.cancel()

        let nextRange = (currentIndex + 1)..<min(currentIndex + 4, cards.count)
        let pendingCards = nextRange
            .map { cards[$0] }
            .filter { $0.translationState != "ru-system" }
        guard !pendingCards.isEmpty else {
            return
        }

        let deck = selectedDeck
        pretranslationTask = Task {
            for card in pendingCards {
                guard !Task.isCancelled else {
                    return
                }

                let translatedCard = await KanjiDataLoader.translateCardIfNeeded(card, deck: deck)
                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    guard selectedDeck == deck else {
                        return
                    }

                    for index in cards.indices where cards[index].kanji == translatedCard.kanji {
                        cards[index] = translatedCard
                    }
                }
            }
        }
    }

    private func resetCurrentAnswer() {
        drawnStrokes.removeAll()
        currentStroke.removeAll()
        feedback.removeAll()
        showsFeedbackInfo = false
        guidedStrokeLimit = 1
        isAnswerVisible = false
    }

    private func updateFeedback(for card: KanjiCard, reveal: Bool) {
        feedback = StrokeEvaluator.evaluate(actual: drawnStrokes, expected: card.strokes)

        if reveal {
            withAnimation(.easeInOut(duration: 0.24)) {
                isAnswerVisible = true
            }
        }
    }
}

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

struct StrokeStepStrip: View {
    let strokes: [KanjiStroke]

    private let columns = [
        GridItem(.adaptive(minimum: 41, maximum: 41), spacing: 4)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            ForEach(strokes.indices, id: \.self) { index in
                StrokeStepView(strokes: strokes, visibleCount: index + 1)
                    .frame(width: 41, height: 41)
            }
        }
    }
}

struct StrokeStepView: View {
    let strokes: [KanjiStroke]
    let visibleCount: Int

    var body: some View {
        Canvas { context, size in
            drawGuides(in: &context, size: size)
            let scale = min(size.width, size.height) / canonicalSize
            context.scaleBy(x: scale, y: scale)

            for stroke in strokes.prefix(visibleCount) {
                let color = stroke.order == visibleCount ? AppPalette.correction : AppPalette.ink.opacity(0.28)
                context.stroke(
                    SVGPathParser.path(from: stroke.pathData),
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .background(AppPalette.surface)
        .border(AppPalette.border.opacity(0.65))
        .overlay(alignment: .topLeading) {
            Text("\(visibleCount)")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(AppPalette.correction)
                .padding(2)
        }
    }

    private func drawGuides(in context: inout GraphicsContext, size: CGSize) {
        var guides = Path()
        guides.move(to: CGPoint(x: size.width / 2, y: 0))
        guides.addLine(to: CGPoint(x: size.width / 2, y: size.height))
        guides.move(to: CGPoint(x: 0, y: size.height / 2))
        guides.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        context.stroke(guides, with: .color(AppPalette.border.opacity(0.25)), lineWidth: 1)
    }
}

enum StrokeFeedbackSeverity {
    case info
    case good
    case minor
    case major
    case missing
    case extra

    var textColor: Color {
        switch self {
        case .info:
            return AppPalette.secondaryText
        case .good:
            return AppPalette.success
        case .minor:
            return AppPalette.warning
        case .major, .missing, .extra:
            return AppPalette.correction
        }
    }

    var actualStrokeColor: Color {
        switch self {
        case .good, .info:
            return AppPalette.ink
        case .minor:
            return AppPalette.warning
        case .major, .missing, .extra:
            return AppPalette.correction
        }
    }

    var expectedStrokeColor: Color {
        switch self {
        case .good, .info:
            return AppPalette.expectedCorrect
        case .minor:
            return AppPalette.expectedWarning
        case .major, .missing, .extra:
            return AppPalette.expectedCorrection
        }
    }

    var requiresCorrectionOverlay: Bool {
        switch self {
        case .minor, .major, .missing:
            return true
        case .info, .good, .extra:
            return false
        }
    }
}

struct StrokeFeedback: Identifiable {
    let id = UUID()
    let strokeIndex: Int?
    let severity: StrokeFeedbackSeverity
    let message: String
}

enum StrokeEvaluator {
    static func evaluateCompletedStrokes(actual: [[CGPoint]], expected: [KanjiStroke]) -> [StrokeFeedback] {
        guard !actual.isEmpty else {
            return []
        }

        var feedback: [StrokeFeedback] = []
        for (index, stroke) in actual.enumerated() {
            guard index < expected.count else {
                feedback.append(
                    StrokeFeedback(
                        strokeIndex: index,
                        severity: .extra,
                        message: "Штрих \(index + 1): лишний."
                    )
                )
                continue
            }

            feedback.append(evaluateStroke(stroke, expected: expected[index], index: index))
        }

        return feedback
    }

    static func evaluate(actual: [[CGPoint]], expected: [KanjiStroke]) -> [StrokeFeedback] {
        guard !actual.isEmpty else {
            return [
                StrokeFeedback(
                    strokeIndex: nil,
                    severity: .info,
                    message: "Пока нет штрихов. Нарисуй кандзи, потом нажми «Проверить»."
                )
            ]
        }

        var feedback: [StrokeFeedback] = []
        let countSeverity: StrokeFeedbackSeverity = actual.count == expected.count ? .good : .major
        let countMessage = actual.count == expected.count
            ? "Количество штрихов похоже на правильное."
            : "Нужно \(expected.count) штриха, сейчас распознано \(actual.count)."
        feedback.append(StrokeFeedback(strokeIndex: nil, severity: countSeverity, message: countMessage))

        for (index, expectedStroke) in expected.enumerated() {
            guard index < actual.count else {
                feedback.append(
                    StrokeFeedback(
                        strokeIndex: index,
                        severity: .missing,
                        message: "Штрих \(index + 1): не найден."
                    )
                )
                continue
            }

            feedback.append(evaluateStroke(actual[index], expected: expectedStroke, index: index))
        }

        if actual.count > expected.count {
            for index in expected.count..<actual.count {
                feedback.append(
                    StrokeFeedback(
                        strokeIndex: index,
                        severity: .extra,
                        message: "Штрих \(index + 1): лишний."
                    )
                )
            }
        }

        return feedback
    }

    private static func evaluateStroke(_ points: [CGPoint], expected: KanjiStroke, index: Int) -> StrokeFeedback {
        guard let start = points.first, let end = points.last else {
            return StrokeFeedback(strokeIndex: index, severity: .missing, message: "Штрих \(index + 1): не найден.")
        }

        let forwardDistance = start.distance(to: expected.startPoint) + end.distance(to: expected.endPoint)
        let reverseDistance = start.distance(to: expected.endPoint) + end.distance(to: expected.startPoint)
        let directionOK = forwardDistance <= reverseDistance
        let shapeOK = strokeShapeLooksRight(points, axis: expected.axis)
        let placementSeverity = placementSeverity(forwardDistance)

        if directionOK && shapeOK && placementSeverity == .good {
            return StrokeFeedback(strokeIndex: index, severity: .good, message: "Штрих \(index + 1): хорошо.")
        }

        var problems: [String] = []
        if !directionOK {
            problems.append("направление обратное")
        }
        if !shapeOK {
            problems.append("форма отличается")
        }
        if placementSeverity != .good {
            problems.append(placementSeverity == .minor ? "чуть смещён" : "далеко от нужного места")
        }

        let severity: StrokeFeedbackSeverity = (!directionOK || placementSeverity == .major) ? .major : .minor
        let prefix = severity == .minor ? "слегка отличается" : "сильно отличается"
        return StrokeFeedback(
            strokeIndex: index,
            severity: severity,
            message: "Штрих \(index + 1): \(prefix) — \(problems.joined(separator: ", "))."
        )
    }

    private static func placementSeverity(_ distance: CGFloat) -> StrokeFeedbackSeverity {
        if distance < 34 {
            return .good
        }

        return distance < 54 ? .minor : .major
    }

    private static func strokeShapeLooksRight(_ points: [CGPoint], axis: StrokeAxis) -> Bool {
        let box = boundingBox(for: points)
        let width = box.width
        let height = box.height

        switch axis {
        case .horizontal:
            return width > height * 1.5
        case .vertical:
            return height > width * 1.5
        case .corner:
            return width > 18 && height > 24
        }
    }

    private static func boundingBox(for points: [CGPoint]) -> CGRect {
        guard let first = points.first else {
            return .zero
        }

        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { box, point in
            box.union(CGRect(origin: point, size: .zero))
        }
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
