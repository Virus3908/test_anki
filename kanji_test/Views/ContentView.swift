import SwiftUI

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

private struct SessionCardMarker: Identifiable {
    let id: String
    let title: String
    let isMastered: Bool
}

private enum MeaningLanguage: String, CaseIterable, Identifiable {
    case russian
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .russian:
            return "Русский"
        case .english:
            return "English"
        }
    }
}

struct ContentView: View {
    @State private var practiceMode: PracticeMode = .kanji
    @State private var cards: [KanjiCard] = []
    @State private var wordCards: [WordStudyCard] = []
    @State private var kanaCards: [KanaStudyCard] = []
    @State private var selectedDeck: KanjiDeck = .jlpt5
    @State private var selectedKanaDeck: KanaDeck = .hiragana
    @State private var previewDeck: KanjiDeck?
    @State private var previewKanaDeck: KanaDeck?
    @State private var previewWordDeck: WordFrequencyDeck?
    @State private var previewCards: [KanjiCard] = []
    @State private var previewKanaCards: [KanaStudyCard] = []
    @State private var previewWordCards: [WordStudyCard] = []
    @State private var previewExpectedCount: Int?
    @State private var selectedPreviewCard: KanjiCard?
    @State private var selectedKanaPreviewCard: KanaStudyCard?
    @State private var selectedWordPreviewCard: WordStudyCard?
    @State private var selectedLinkedKanjiCard: KanjiCard?
    @State private var isPreviewDetailPresented = false
    @State private var isLinkedKanjiPresented = false
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
    @State private var masteredKanjiKeys: Set<String> = []
    @State private var masteredWordKeys: Set<String> = []
    @State private var masteredKanaKeys: Set<String> = []
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
    @State private var isSettingsPresented = false
    @State private var meaningLanguage: MeaningLanguage = .russian
    @State private var wordMeaningTranslations: [String: String] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if hasStartedTraining {
                    activeTrainingView()
                } else if let previewDeck {
                    deckPreviewView(for: previewDeck)
                } else if let previewKanaDeck {
                    kanaPreviewView(for: previewKanaDeck)
                } else if let previewWordDeck {
                    wordPreviewView(for: previewWordDeck)
                } else {
                    startView()
                }
            }
            .navigationTitle(hasStartedTraining ? "Kanji Trainer" : previewDeck == nil && previewKanaDeck == nil && previewWordDeck == nil ? "Набор карточек" : "Колода")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppPalette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .disabled(isLoadingDeck)
                }
            }
            .sheet(isPresented: $isSettingsPresented) {
                settingsView()
            }
            .onChange(of: meaningLanguage) {
                handleMeaningLanguageChange()
            }
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

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if practiceMode == .kana {
                            ForEach(KanaDeck.allCases) { deck in
                                kanaDeckButton(for: deck)
                            }
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

    private func settingsView() -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    translationSettingsView()
                    frontSettingsView()
                }
                .padding(20)
            }
            .background(AppPalette.background)
            .foregroundStyle(AppPalette.text)
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        isSettingsPresented = false
                    }
                }
            }
        }
    }

    private func translationSettingsView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Перевод")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.secondaryText)
                .textCase(.uppercase)

            Picker("Язык значений", selection: $meaningLanguage) {
                ForEach(MeaningLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }
            .pickerStyle(.segmented)

            Text(meaningLanguage == .russian ? "Показываем русский перевод через внутренний переводчик." : "Показываем исходные английские значения из источников.")
                .font(.caption)
                .foregroundStyle(AppPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
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

    private func handleMeaningLanguageChange() {
        guard meaningLanguage == .russian else {
            previewTranslationTask?.cancel()
            pretranslationTask?.cancel()
            return
        }

        if let previewDeck {
            schedulePreviewTranslations(for: previewDeck)
        }
        scheduleNextCardTranslation()
    }

    private var trainingTitle: String {
        switch practiceMode {
        case .kanji:
            return selectedDeck.title
        case .words:
            return "Слова: \(selectedWordDeck.title)"
        case .kana:
            return selectedKanaDeck.title
        }
    }

    private var startSubtitle: String {
        switch practiceMode {
        case .kanji:
            return "Первый запуск скачает весь пакет из kanjiapi.dev и сохранит его в кэш."
        case .words:
            return "Слова берутся локально из полного словаря и группируются диапазонами по частоте."
        case .kana:
            return "Хирагана и катакана с просмотром карточек и тренировкой письма."
        }
    }

    private func loadReviewMemory() async {
        await Task.yield()
        reviewStore = KanjiReviewStore.load()
    }

    private func kanaDeckButton(for deck: KanaDeck) -> some View {
        Button {
            openKanaPreview(deck)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(deck.title)
                        .font(.headline)
                    Text("\(deck.cards.count) карточек")
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
            openWordPreview(deck)
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
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.white)
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

    private func kanaPreviewView(for deck: KanaDeck) -> some View {
        ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Button("", systemImage: "chevron.left") {
                        closeKanaPreview()
                    }
                    .buttonStyle(.bordered)
                    .tint(AppPalette.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(deck.title)
                            .font(.title2.weight(.bold))
                        Text(kanaPreviewStatus(for: deck))
                            .font(.caption)
                            .foregroundStyle(AppPalette.secondaryText)
                    }

                    Spacer()
                }

                Button {
                    startKanaTraining(deck: deck, cards: previewKanaCards.shuffled())
                } label: {
                    HStack {
                        Image(systemName: "shuffle")
                        Text("Начать тренировку")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(previewKanaCards.count)")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.white)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.accent)
                .disabled(previewKanaCards.isEmpty)

                ScrollView(.vertical) {
                    LazyVGrid(columns: kanaPreviewColumns, spacing: 10) {
                        ForEach(previewKanaCards) { card in
                            kanaPreviewTile(for: card)
                        }
                    }
                    .padding(.bottom, 20)
                }

                if isLoadingDeck {
                    ProgressView("Загружаю штрихи")
                        .foregroundStyle(AppPalette.secondaryText)
                        .tint(AppPalette.accent)
                }
            }
            .padding(20)
            .foregroundStyle(AppPalette.text)
        }
        .sheet(isPresented: $isPreviewDetailPresented) {
            selectedKanaPreviewCard = nil
            previewSwipeDirection = 0
        } content: {
            if let selectedKanaPreviewCard {
                kanaPreviewDetail(for: selectedKanaPreviewCard, deck: deck)
            }
        }
    }

    private func wordPreviewView(for deck: WordFrequencyDeck) -> some View {
        ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Button("", systemImage: "chevron.left") {
                        closeWordPreview()
                    }
                    .buttonStyle(.bordered)
                    .tint(AppPalette.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(deck.title)
                            .font(.title2.weight(.bold))
                        Text(wordPreviewStatus)
                            .font(.caption)
                            .foregroundStyle(AppPalette.secondaryText)
                    }

                    Spacer()
                }

                Button {
                    startWordTraining(with: previewWordCards.shuffled())
                } label: {
                    HStack {
                        Image(systemName: "shuffle")
                        Text("Начать тренировку")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(previewWordCards.count)")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.white)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.accent)
                .disabled(previewWordCards.isEmpty)

                ScrollView(.vertical) {
                    LazyVGrid(columns: wordPreviewColumns, spacing: 10) {
                        ForEach(previewWordCards) { card in
                            wordPreviewTile(for: card)
                        }
                    }
                    .padding(.bottom, 20)
                }

                if isLoadingDeck {
                    ProgressView("Загружаю слова")
                        .foregroundStyle(AppPalette.secondaryText)
                        .tint(AppPalette.accent)
                }
            }
            .padding(20)
            .foregroundStyle(AppPalette.text)
        }
        .sheet(isPresented: $isPreviewDetailPresented) {
            selectedWordPreviewCard = nil
            selectedLinkedKanjiCard = nil
            isLinkedKanjiPresented = false
            previewSwipeDirection = 0
        } content: {
            if let selectedWordPreviewCard {
                wordPreviewDetail(for: selectedWordPreviewCard, deck: deck)
            }
        }
    }

    private var kanjiPreviewColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
    }

    private var kanaPreviewColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
    }

    private var wordPreviewColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    private var wordPreviewStatus: String {
        isLoadingDeck ? "Загружаю словарь" : "\(previewWordCards.count) слов"
    }

    private func kanaPreviewStatus(for deck: KanaDeck) -> String {
        isLoadingDeck ? "Загружаю штрихи из KanjiVG" : "\(previewKanaCards.count) карточек из KanjiVG"
    }

    private var deckPreviewStatus: String {
        if let previewExpectedCount {
            return "\(previewCards.count) / \(previewExpectedCount) загружено"
        }

        return "\(previewCards.count) загружено"
    }

    private func wordPreviewTile(for card: WordStudyCard) -> some View {
        Button {
            selectedWordPreviewCard = card
            previewSwipeDirection = 0
            isPreviewDetailPresented = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.reading)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(card.word)
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Text(displayedWordMeaning(for: card))
                    .font(.caption)
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.border.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func wordPreviewDetail(for card: WordStudyCard, deck: WordFrequencyDeck) -> some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    wordFullCard(for: card)

                    Button {
                        selectedWordPreviewCard = nil
                        isPreviewDetailPresented = false
                        startWordTraining(with: [card])
                    } label: {
                        HStack {
                            Image(systemName: "pencil.and.scribble")
                            Text("Практиковать слово")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.accent)
                }
                .padding(20)
            }
            .background(AppPalette.background)
            .id(card.id)
            .transition(previewDetailTransition)
            .simultaneousGesture(wordPreviewCardSwipeGesture(for: card, in: deck))
        }
        .sheet(isPresented: $isLinkedKanjiPresented) {
            selectedLinkedKanjiCard = nil
        } content: {
            if let selectedLinkedKanjiCard {
                kanjiPreviewDetail(for: selectedLinkedKanjiCard)
            }
        }
    }

    private func wordFullCard(for card: WordStudyCard) -> some View {
        wordFullCardContent(for: card)
            .padding(18)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.border.opacity(0.65), lineWidth: 1)
            )
    }

    private func wordFullCardContent(for card: WordStudyCard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 6) {
                Text(card.word)
                    .font(.system(size: 64, weight: .regular, design: .serif))
                    .foregroundStyle(AppPalette.text)
                    .minimumScaleFactor(0.42)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                Text(card.reading)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)

            detailBlock("Перевод") {
                Text(displayedWordMeaning(for: card))
                    .foregroundStyle(AppPalette.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            detailBlock("Состав") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(card.kanjiCards.indices, id: \.self) { index in
                        wordComponentLink(for: card.kanjiCards[index])
                    }
                }
            }
        }
        .task(id: "\(card.id)-\(meaningLanguage.rawValue)") {
            await translateWordMeaningIfNeeded(for: card)
        }
    }

    private func wordComponentLink(for card: KanjiCard) -> some View {
        Button {
            selectedLinkedKanjiCard = card
            isLinkedKanjiPresented = true
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(card.kanji)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppPalette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(wordComponentSubtitle(for: card))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.border.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func wordComponentSubtitle(for card: KanjiCard) -> String {
        if let meaning = displayedKanjiMeanings(for: card).first, !meaning.isEmpty {
            return meaning
        }

        if let reading = card.kunyomi.first ?? card.onyomi.first, !reading.isEmpty {
            return reading
        }

        return "знак"
    }

    private func kanaPreviewTile(for card: KanaStudyCard) -> some View {
        Button {
            selectedKanaPreviewCard = card
            previewSwipeDirection = 0
            isPreviewDetailPresented = true
        } label: {
            VStack(spacing: 4) {
                Text(card.character)
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .frame(maxWidth: .infinity)
                    .minimumScaleFactor(0.55)

                Text(card.reading)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(height: 14)
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.border.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func kanaPreviewDetail(for card: KanaStudyCard, deck: KanaDeck) -> some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    kanaPreviewCardContent(for: card)

                    Button {
                        selectedKanaPreviewCard = nil
                        isPreviewDetailPresented = false
                        startKanaTraining(deck: deck, cards: [card], guided: true)
                    } label: {
                        HStack {
                            Image(systemName: "pencil.and.scribble")
                            Text("Тренировать этот знак")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.accent)
                }
                .padding(20)
            }
            .background(AppPalette.background)
            .foregroundStyle(AppPalette.text)
            .id(card.character)
            .transition(previewDetailTransition)
            .simultaneousGesture(kanaPreviewCardSwipeGesture(for: card, in: deck))
        }
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

                Text(displayedKanjiMeanings(for: card).prefix(2).joined(separator: ", "))
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
                    cardBackContent(for: card)
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
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.accent)
                }
                .padding(20)
            }
            .background(AppPalette.background)
            .foregroundStyle(AppPalette.text)
            .id(card.kanji)
            .transition(previewDetailTransition)
            .simultaneousGesture(previewCardSwipeGesture(for: card))
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

    private func wordPreviewCardSwipeGesture(for card: WordStudyCard, in deck: WordFrequencyDeck) -> some Gesture {
        DragGesture(minimumDistance: 35)
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height
                guard abs(width) > abs(height) * 1.25, abs(width) > 55 else {
                    return
                }

                guard let index = previewWordCards.firstIndex(where: { $0.id == card.id }) else {
                    return
                }

                if width < 0, let nextCard = previewWordCards[safe: index + 1] {
                    previewSwipeDirection = -1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedWordPreviewCard = nextCard
                    }
                } else if width > 0, let previousCard = previewWordCards[safe: index - 1] {
                    previewSwipeDirection = 1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedWordPreviewCard = previousCard
                    }
                }
            }
    }

    private func kanaPreviewCardSwipeGesture(for card: KanaStudyCard, in deck: KanaDeck) -> some Gesture {
        DragGesture(minimumDistance: 35)
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height
                guard abs(width) > abs(height) * 1.25, abs(width) > 55 else {
                    return
                }

                guard let index = previewKanaCards.firstIndex(where: { $0.character == card.character }) else {
                    return
                }

                if width < 0, let nextCard = previewKanaCards[safe: index + 1] {
                    previewSwipeDirection = -1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedKanaPreviewCard = nextCard
                    }
                } else if width > 0, let previousCard = previewKanaCards[safe: index - 1] {
                    previewSwipeDirection = 1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedKanaPreviewCard = previousCard
                    }
                }
            }
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
        case .kana:
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
        ZStack {
            wordCardFront(for: wordCard)
                .opacity(isAnswerVisible ? 0 : 1)
                .rotation3DEffect(.degrees(isAnswerVisible ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            ScrollView {
                wordFullCardContent(for: wordCard)
            }
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
        .gesture(cardSwipeGesture())
        .task(id: "\(wordCard.id)-\(meaningLanguage.rawValue)") {
            await translateWordMeaningIfNeeded(for: wordCard)
        }
    }

    private func wordCardFront(for wordCard: WordStudyCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Задание")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.secondaryText)
                .textCase(.uppercase)

            wordFrontFields(for: wordCard)

            if !showsPromptCharacters && !showsPromptReading && !showsPromptMeaning {
                Text("Нарисуй символы слова по памяти.")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppPalette.text)
            }

            Spacer(minLength: 16)

            Text("Проверка покажет слово, чтение, перевод и состав.")
                .foregroundStyle(AppPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                Text(displayedWordMeaning(for: wordCard))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func kanaStudyCard(for kanaCard: KanaStudyCard) -> some View {
        ZStack {
            kanaCardFront(for: kanaCard)
                .opacity(isAnswerVisible ? 0 : 1)
                .rotation3DEffect(.degrees(isAnswerVisible ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            kanaCardBack(for: kanaCard)
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
        .gesture(cardSwipeGesture())
    }

    private func kanaCardFront(for kanaCard: KanaStudyCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Задание")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.secondaryText)
                .textCase(.uppercase)

            detailBlock("Чтение") {
                Text(kanaCard.reading)
                    .font(.largeTitle.weight(.bold))
            }

            Spacer(minLength: 16)

            Text("Нарисуй знак каны по памяти.")
                .font(.title2.weight(.semibold))

            Text("Проверка покажет оригинал и сравнение штрихов.")
                .foregroundStyle(AppPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func kanaPreviewCardContent(for kanaCard: KanaStudyCard) -> some View {
        kanaCardBackContent(for: kanaCard)
            .padding(18)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.border.opacity(0.65), lineWidth: 1)
            )
    }

    private func kanaCardBack(for kanaCard: KanaStudyCard) -> some View {
        ScrollView {
            kanaCardBackContent(for: kanaCard)
        }
    }

    private func kanaCardBackContent(for kanaCard: KanaStudyCard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 18) {
                Text(kanaCard.character)
                    .font(.system(size: 82, weight: .regular, design: .serif))
                    .foregroundStyle(AppPalette.text)
                    .frame(width: 112, height: 112)
                    .background(AppPalette.surface)
                    .border(AppPalette.border.opacity(0.65))

                VStack(alignment: .leading, spacing: 8) {
                    detailBlock("Кана") {
                        Text(kanaCard.character)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppPalette.text)
                    }

                    detailBlock("Чтение") {
                        Text(kanaCard.reading)
                            .foregroundStyle(AppPalette.text)
                    }

                    detailBlock("Штрихи") {
                        Text("\(kanaCard.strokes.count)")
                            .foregroundStyle(AppPalette.text)
                    }
                }
            }

            if !kanaCard.strokes.isEmpty {
                detailBlock("Порядок штрихов") {
                    StrokeStepStrip(strokes: kanaCard.strokes)
                }
            }
        }
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
        VStack(alignment: .leading, spacing: 8) {
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

            let markers = sessionCardMarkers
            if !markers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(markers) { marker in
                            sessionCardMarker(marker)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.accent)
    }

    private var sessionCardMarkers: [SessionCardMarker] {
        switch practiceMode {
        case .kanji:
            return uniqueMarkers(
                from: cards,
                key: \.kanji,
                title: \.kanji,
                masteredKeys: masteredKanjiKeys
            )
        case .words:
            return uniqueMarkers(
                from: wordCards,
                key: \.id,
                title: \.word,
                masteredKeys: masteredWordKeys
            )
        case .kana:
            return uniqueMarkers(
                from: kanaCards,
                key: \.character,
                title: \.character,
                masteredKeys: masteredKanaKeys
            )
        }
    }

    private func uniqueMarkers<Item>(
        from items: [Item],
        key: KeyPath<Item, String>,
        title: KeyPath<Item, String>,
        masteredKeys: Set<String>
    ) -> [SessionCardMarker] {
        var seen: Set<String> = []
        return items.compactMap { item in
            let itemKey = item[keyPath: key]
            guard seen.insert(itemKey).inserted else {
                return nil
            }

            return SessionCardMarker(
                id: itemKey,
                title: item[keyPath: title],
                isMastered: masteredKeys.contains(itemKey)
            )
        }
    }

    private func sessionCardMarker(_ marker: SessionCardMarker) -> some View {
        Text(marker.title)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(marker.isMastered ? Color.white : AppPalette.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(marker.isMastered ? AppPalette.success : AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(marker.isMastered ? AppPalette.success : AppPalette.border.opacity(0.55), lineWidth: 1)
            )
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
        .gesture(cardSwipeGesture())
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
                Text(displayedKanjiMeanings(for: card).joined(separator: ", "))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func cardBack(for card: KanjiCard) -> some View {
        ScrollView {
            cardBackContent(for: card)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func cardBackContent(for card: KanjiCard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 18) {
                Text(card.kanji)
                    .font(.system(size: 82, weight: .regular, design: .serif))
                    .foregroundStyle(AppPalette.text)
                    .frame(width: 112, height: 112)
                    .background(AppPalette.surface)
                    .border(AppPalette.border.opacity(0.65))

                VStack(alignment: .leading, spacing: 8) {
                    detailBlock("Кандзи") {
                        Text(card.kanji)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppPalette.text)
                    }

                    detailBlock("Онъёми") {
                        Text(readingsText(card.onyomi))
                            .foregroundStyle(AppPalette.text)
                    }

                    detailBlock("Кунъёми") {
                        Text(kunyomiText(for: card.kunyomi))
                            .foregroundStyle(AppPalette.text)
                    }

                    detailBlock("Порядок черт") {
                        StrokeStepStrip(strokes: card.strokes)
                    }

                    detailBlock("Значения") {
                        Text(displayedKanjiMeanings(for: card).joined(separator: ", "))
                            .foregroundStyle(AppPalette.text)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            let examples = displayedKanjiExamples(for: card)
            if !examples.isEmpty {
                section("Примеры") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(examples) { example in
                            Text("\(example.word) - \(example.reading) - \(example.meaning)")
                                .foregroundStyle(AppPalette.text)
                        }
                    }
                }
            }
        }
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

    private func displayedKanjiMeanings(for card: KanjiCard) -> [String] {
        switch meaningLanguage {
        case .russian:
            return card.meanings
        case .english:
            return card.sourceMeanings ?? card.meanings
        }
    }

    private func displayedKanjiExamples(for card: KanjiCard) -> [KanjiExample] {
        switch meaningLanguage {
        case .russian:
            return card.examples
        case .english:
            return card.sourceExamples ?? card.examples
        }
    }

    private func displayedWordMeaning(for card: WordStudyCard) -> String {
        switch meaningLanguage {
        case .russian:
            return wordMeaningTranslations[card.id] ?? RussianMeaningTranslator.translateLocally([card.meaning]).first ?? card.meaning
        case .english:
            return card.meaning
        }
    }

    private func translateWordMeaningIfNeeded(for card: WordStudyCard) async {
        guard meaningLanguage == .russian, wordMeaningTranslations[card.id] == nil else {
            return
        }

        let translatedMeaning = await RussianMeaningTranslator.translate([card.meaning]).first ?? card.meaning
        await MainActor.run {
            guard meaningLanguage == .russian, wordMeaningTranslations[card.id] == nil else {
                return
            }

            wordMeaningTranslations[card.id] = translatedMeaning
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
        ratingActionButton(title, color: color) {
            applyReview(rating, to: card)
        }
        .disabled(isPreparingCard)
    }

    private func ratingActionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.white)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
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
                    expectedStrokes: expectedStrokesForCurrentCard(card),
                    feedback: feedback,
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
                        undoCurrentStroke()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(drawnStrokes.isEmpty)

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
                .disabled(currentIndex <= 0 || isPreparingCard)

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
                    moveToPreviousCard()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentIndex <= 0 || isPreparingCard)

                Spacer(minLength: 12)

                HStack(spacing: 10) {
                    ratingActionButton("-", color: feedback.isEmpty ? AppPalette.mutedText : AppPalette.correction) {
                        applyWordReview(.again)
                    }
                    ratingActionButton("~", color: feedback.isEmpty ? AppPalette.mutedText : AppPalette.warning) {
                        applyWordReview(.hard)
                    }
                    ratingActionButton("+", color: feedback.isEmpty ? AppPalette.mutedText : AppPalette.success) {
                        applyWordReview(.good)
                    }
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
        let expectedCard = kanjiCard(for: kanaCard)

        return VStack(spacing: 8) {
            ZStack {
                DrawingBoard(
                    drawnStrokes: $drawnStrokes,
                    currentStroke: $currentStroke,
                    expectedStrokes: expectedStrokesForCurrentCard(expectedCard),
                    feedback: feedback,
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
                        undoCurrentStroke()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(drawnStrokes.isEmpty)

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
                .disabled(currentIndex <= 0 || isPreparingCard)

                Spacer(minLength: 12)

                HStack(spacing: 10) {
                    ratingActionButton("-", color: feedback.isEmpty ? AppPalette.mutedText : AppPalette.correction) {
                        applyKanaReview(.again)
                    }
                    ratingActionButton("~", color: feedback.isEmpty ? AppPalette.mutedText : AppPalette.warning) {
                        applyKanaReview(.hard)
                    }
                    ratingActionButton("+", color: feedback.isEmpty ? AppPalette.mutedText : AppPalette.success) {
                        applyKanaReview(.good)
                    }
                }
                .disabled(feedback.isEmpty)

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

    private func resetSessionProgress(total: Int) {
        sessionTotalCards = total
        sessionCompletedCards = 0
        masteredKanjiKeys.removeAll()
        masteredWordKeys.removeAll()
        masteredKanaKeys.removeAll()
    }

    private func clearDeckCache() {
        pretranslationTask?.cancel()
        pretranslationTask = nil
        deckPreviewTask?.cancel()
        deckPreviewTask = nil
        previewTranslationTask?.cancel()
        previewTranslationTask = nil
        KanjiDataLoader.clearCache()
        KanaDataLoader.clearCache()
        cards.removeAll()
        wordCards.removeAll()
        kanaCards.removeAll()
        previewCards.removeAll()
        previewKanaCards.removeAll()
        previewWordCards.removeAll()
        previewExpectedCount = nil
        previewDeck = nil
        previewKanaDeck = nil
        previewWordDeck = nil
        selectedPreviewCard = nil
        selectedKanaPreviewCard = nil
        selectedWordPreviewCard = nil
        selectedLinkedKanjiCard = nil
        currentIndex = 0
        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
        resetSessionProgress(total: 0)
        resetCurrentAnswer()
    }

    private func openDeckPreview(_ deck: KanjiDeck) {
        deckPreviewTask?.cancel()
        previewTranslationTask?.cancel()
        previewDeck = deck
        previewKanaDeck = nil
        previewWordDeck = nil
        previewWordCards.removeAll()
        previewKanaCards.removeAll()
        selectedKanaPreviewCard = nil
        selectedWordPreviewCard = nil
        selectedPreviewCard = nil
        isPreviewDetailPresented = false
        previewCards.removeAll()
        previewExpectedCount = nil
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

    private func openKanaPreview(_ deck: KanaDeck) {
        selectedKanaDeck = deck
        previewKanaDeck = deck
        previewDeck = nil
        previewWordDeck = nil
        previewWordCards.removeAll()
        previewKanaCards = deck.baseCards
        selectedPreviewCard = nil
        selectedWordPreviewCard = nil
        selectedKanaPreviewCard = nil
        isPreviewDetailPresented = false
        isLoadingDeck = true
        resetCurrentAnswer()

        Task {
            let loadedCards = await KanaDataLoader.loadCards(deck: deck)
            await MainActor.run {
                guard previewKanaDeck == deck else {
                    return
                }

                previewKanaCards = loadedCards
                isLoadingDeck = false
            }
        }
    }

    private func closeKanaPreview() {
        previewKanaDeck = nil
        previewKanaCards.removeAll()
        selectedPreviewCard = nil
        selectedKanaPreviewCard = nil
        isPreviewDetailPresented = false
        isLoadingDeck = false
        resetCurrentAnswer()
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
        resetSessionProgress(total: Set(cards.map(\.kanji)).count)
        isGuidedSingleKanjiPractice = guided
        hasStartedTraining = true
        resetCurrentAnswer()
        scheduleNextCardTranslation()
    }

    private func schedulePreviewTranslations(for deck: KanjiDeck) {
        guard meaningLanguage == .russian else {
            return
        }

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

    private func openWordPreview(_ deck: WordFrequencyDeck) {
        guard !isLoadingDeck else {
            return
        }

        selectedWordDeck = deck
        previewWordDeck = deck
        previewDeck = nil
        previewKanaDeck = nil
        selectedWordPreviewCard = nil
        selectedPreviewCard = nil
        selectedKanaPreviewCard = nil
        previewWordCards.removeAll()
        isPreviewDetailPresented = false
        isLoadingDeck = true

        Task {
            let allWords = await WordDataLoader.loadWords()
            let preparedWords = deck.cards(from: allWords)

            await MainActor.run {
                guard previewWordDeck == deck else {
                    return
                }

                previewWordCards = preparedWords
                isLoadingDeck = false
            }
        }
    }

    private func closeWordPreview() {
        previewWordDeck = nil
        previewWordCards.removeAll()
        selectedWordPreviewCard = nil
        selectedLinkedKanjiCard = nil
        isPreviewDetailPresented = false
        isLinkedKanjiPresented = false
        isLoadingDeck = false
        resetCurrentAnswer()
    }

    private func startWordTraining(with trainingCards: [WordStudyCard]) {
        guard !trainingCards.isEmpty else {
            return
        }

        pretranslationTask?.cancel()
        pretranslationTask = nil
        practiceMode = .words
        previewWordDeck = nil
        cards.removeAll()
        kanaCards.removeAll()
        wordCards = trainingCards
        currentIndex = 0
        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
        resetSessionProgress(total: Set(wordCards.map(\.id)).count)
        isGuidedSingleKanjiPractice = false
        isLoadingDeck = false
        hasStartedTraining = true
        resetCurrentAnswer()
    }

    private func startKanaTraining(deck: KanaDeck, cards trainingCards: [KanaStudyCard]? = nil, guided: Bool = false) {
        pretranslationTask?.cancel()
        pretranslationTask = nil
        selectedKanaDeck = deck
        practiceMode = .kana
        previewKanaDeck = nil
        cards.removeAll()
        wordCards.removeAll()
        kanaCards = trainingCards ?? deck.cards.shuffled()
        currentIndex = 0
        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
        resetSessionProgress(total: Set(kanaCards.map(\.character)).count)
        isGuidedSingleKanjiPractice = guided
        hasStartedTraining = !kanaCards.isEmpty
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
        if meaningLanguage == .russian, let firstCard = orderedCards.first {
            orderedCards[0] = await KanjiDataLoader.translateCardIfNeeded(firstCard, deck: selectedDeck)
        }

        cards = orderedCards
        wordCards = WordStudyCard.build(from: orderedCards)
        currentIndex = 0
        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
        resetSessionProgress(total: practiceMode == .words ? Set(wordCards.map(\.id)).count : Set(orderedCards.map(\.kanji)).count)
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

    private func kanjiCard(for kanaCard: KanaStudyCard) -> KanjiCard {
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

    private func guidedExpectedStrokes(for card: KanjiCard) -> [KanjiStroke] {
        guard !card.strokes.isEmpty else {
            return []
        }

        return Array(card.strokes.prefix(min(guidedStrokeLimit, card.strokes.count)))
    }

    private func expectedStrokesForCurrentCard(_ card: KanjiCard) -> [KanjiStroke] {
        guard isGuidedSingleKanjiPractice else {
            return isAnswerVisible || !feedback.isEmpty ? card.strokes : []
        }

        return guidedExpectedStrokes(for: card)
    }

    private func expectedStrokesForCurrentWordKanji(_ card: KanjiCard) -> [KanjiStroke] {
        isAnswerVisible || !currentWordFeedback.isEmpty ? card.strokes : []
    }

    private func undoCurrentStroke() {
        _ = drawnStrokes.popLast()
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

    private func handleGuidedStrokeFinished(_ card: KanjiCard) {
        guard isGuidedSingleKanjiPractice, !card.strokes.isEmpty else {
            return
        }

        feedback = StrokeEvaluator.evaluateCompletedStrokes(actual: drawnStrokes, expected: card.strokes)
        let latestSeverity = feedback.last { $0.strokeIndex == drawnStrokes.count - 1 }?.severity

        if latestSeverity == .good || latestSeverity == .minor {
            advanceGuidedStrokeOrReveal(card)
        }
    }

    private func advanceGuidedStrokeOrReveal(_ card: KanjiCard) {
        guard isGuidedSingleKanjiPractice, !card.strokes.isEmpty else {
            updateFeedback(for: card, reveal: true)
            return
        }

        if drawnStrokes.count >= card.strokes.count {
            updateFeedback(for: card, reveal: true)
            return
        }

        guidedStrokeLimit = min(max(guidedStrokeLimit + 1, drawnStrokes.count + 1), card.strokes.count)
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

        let wordCard = wordCards[currentIndex]
        switch rating {
        case .again:
            masteredWordKeys.remove(wordCard.id)
            scheduleWordRepeat(wordCard, after: 2)
        case .hard:
            masteredWordKeys.remove(wordCard.id)
            scheduleWordRepeat(wordCard, after: 5)
        case .good:
            masteredWordKeys.insert(wordCard.id)
            removeFutureWordRepeats(after: currentIndex, key: wordCard.id)
        }

        sessionCompletedCards = masteredWordKeys.count
        advanceToNextWordOrFinish()
    }

    private func scheduleWordRepeat(_ wordCard: WordStudyCard, after offset: Int) {
        removeFutureWordRepeats(after: currentIndex, key: wordCard.id)
        let insertIndex = min(currentIndex + offset, wordCards.count)
        wordCards.insert(wordCard, at: insertIndex)
    }

    private func removeFutureWordRepeats(after index: Int, key: String) {
        guard index + 1 < wordCards.count else {
            return
        }

        for cardIndex in wordCards.indices.reversed() where cardIndex > index && wordCards[cardIndex].id == key {
            wordCards.remove(at: cardIndex)
        }
    }

    private func advanceToNextWordOrFinish() {
        guard sessionCompletedCards < sessionTotalCards else {
            finishDeck()
            return
        }

        guard currentIndex < wordCards.count - 1 else {
            return
        }

        currentIndex += 1
        currentWordKanjiIndex = 0
        completedWordDrawings.removeAll()
        wordFeedbackByKanji.removeAll()
        resetCurrentAnswer()
        scrollToTopToken += 1
    }

    private func applyKanaReview(_ rating: ReviewRating) {
        guard kanaCards.indices.contains(currentIndex), !isPreparingCard else {
            return
        }

        let kanaCard = kanaCards[currentIndex]
        switch rating {
        case .again:
            masteredKanaKeys.remove(kanaCard.character)
            scheduleKanaRepeat(kanaCard, after: 2)
        case .hard:
            masteredKanaKeys.remove(kanaCard.character)
            scheduleKanaRepeat(kanaCard, after: 5)
        case .good:
            masteredKanaKeys.insert(kanaCard.character)
            removeFutureKanaRepeats(after: currentIndex, key: kanaCard.character)
        }

        sessionCompletedCards = masteredKanaKeys.count
        advanceToNextKanaOrFinish()
    }

    private func scheduleKanaRepeat(_ kanaCard: KanaStudyCard, after offset: Int) {
        removeFutureKanaRepeats(after: currentIndex, key: kanaCard.character)
        let insertIndex = min(currentIndex + offset, kanaCards.count)
        kanaCards.insert(kanaCard, at: insertIndex)
    }

    private func removeFutureKanaRepeats(after index: Int, key: String) {
        guard index + 1 < kanaCards.count else {
            return
        }

        for cardIndex in kanaCards.indices.reversed() where cardIndex > index && kanaCards[cardIndex].character == key {
            kanaCards.remove(at: cardIndex)
        }
    }

    private func advanceToNextKanaOrFinish() {
        guard sessionCompletedCards < sessionTotalCards else {
            finishDeck()
            return
        }

        guard currentIndex < kanaCards.count - 1 else {
            return
        }

        currentIndex += 1
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
            masteredKanjiKeys.remove(card.kanji)
            scheduleKanjiRepeat(card, after: 2)
        case .hard:
            masteredKanjiKeys.remove(card.kanji)
            scheduleKanjiRepeat(card, after: 5)
        case .good:
            masteredKanjiKeys.insert(card.kanji)
            removeFutureKanjiRepeats(after: currentIndex, key: card.kanji)
        }

        sessionCompletedCards = masteredKanjiKeys.count
        await advanceToNextKanjiOrFinish()
    }

    private func scheduleKanjiRepeat(_ card: KanjiCard, after offset: Int) {
        removeFutureKanjiRepeats(after: currentIndex, key: card.kanji)
        let insertIndex = min(currentIndex + offset, cards.count)
        cards.insert(card, at: insertIndex)
    }

    private func removeFutureKanjiRepeats(after index: Int, key: String) {
        guard index + 1 < cards.count else {
            return
        }

        for cardIndex in cards.indices.reversed() where cardIndex > index && cards[cardIndex].kanji == key {
            cards.remove(at: cardIndex)
        }
    }

    private func advanceToNextKanjiOrFinish() async {
        guard sessionCompletedCards < sessionTotalCards else {
            finishDeck()
            return
        }

        guard currentIndex < cards.count - 1 else {
            return
        }

        await prepareAndMoveToCard(at: currentIndex + 1)
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
        resetSessionProgress(total: 0)
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
        case .kana:
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
        let preparedCard = meaningLanguage == .russian && card.translationState != "ru-system"
            ? await KanjiDataLoader.translateCardIfNeeded(card, deck: deck)
            : card

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

        guard meaningLanguage == .russian else {
            return
        }

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
