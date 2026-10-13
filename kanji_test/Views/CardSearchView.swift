import SwiftUI
import AnkiImport

/// Экран поиска карточек — sheet из шапки превью колоды.
///
/// Тайлы и превью те же, что в превью колод. Нажатия по тайлам открывают
/// linked-превью: оно не зависит от выбранной колоды, поэтому подходит
/// для карточек, найденных по всему приложению.
struct CardSearchView: View, CardContentRendering {
    let deckID: String? = nil
    let coordinator: StudyCoordinator
    let settings: StudyPreferences
    let translationState: TranslationViewModel
    let reviewStore: StudyProgressStore
    let onPractice: (PracticeSelection) -> Void
    private let fieldPreferences = AnkiFieldDisplayPreferences.shared

    @State private var model: CardSearchViewModel
    @State private var query = ""
    @State private var retryAnkiTask: Task<Void, Never>?
    @State private var openingAnkiTask: Task<Void, Never>?
    @State private var selectedGrammarRule: GrammarRule?
    @State private var selectedAnkiCard: AnkiStudyCard?
    @Environment(\.dismiss) private var dismiss

    init(
        scope: CardSearchViewModel.Scope,
        coordinator: StudyCoordinator,
        settings: StudyPreferences,
        translationState: TranslationViewModel,
        reviewStore: StudyProgressStore,
        ankiModel: AnkiLibraryViewModel? = nil,
        onPractice: @escaping (PracticeSelection) -> Void
    ) {
        self.coordinator = coordinator
        self.settings = settings
        self.translationState = translationState
        self.reviewStore = reviewStore
        self.onPractice = onPractice
        _model = State(initialValue: CardSearchViewModel(
            scope: scope,
            translationState: translationState,
            ankiModel: ankiModel
        ))
    }

    var body: some View {
        @Bindable var coordinator = coordinator

        return ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                previewHeader(title: "Поиск", subtitle: subtitle, onBack: { dismiss() })

                searchField

                if model.isPreparing {
                    CenteredLoadingIndicator(title: "Готовлю поиск")
                        .padding(.vertical, 10)
                } else if let error = model.loadError {
                    Text(error).font(.caption).foregroundStyle(AppPalette.correction)
                    Button("Повторить") { Task { await model.prepare() } }
                } else {
                    if !model.unavailableAnkiImports.isEmpty {
                        Text("Некоторые Anki-колоды временно недоступны для поиска.")
                            .font(.caption).foregroundStyle(AppPalette.correction)
                        Button("Повторить загрузку Anki") {
                            retryAnkiTask?.cancel()
                            retryAnkiTask = Task { await model.retryAnkiSearch() }
                        }
                    }
                    if let error = model.searchError {
                        Text(error).font(.caption).foregroundStyle(AppPalette.correction)
                    }
                    resultSummary

                    ScrollView(.vertical) {
                        resultContent
                        .padding(.horizontal, 4)
                        .padding(.bottom, 44)
                    }
                    .mask { BottomScrollMask() }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 12)
            .padding(.top, 20)
            .padding(.bottom, 4)
            .foregroundStyle(AppPalette.text)
        }
        .task {
            await model.prepare()
            // Пользователь мог начать печатать, пока готовился индекс.
            await model.updateResults(for: query)
        }
        .onChange(of: query) { model.queryChanged(to: query) }
        .onDisappear { model.close(); openingAnkiTask?.cancel(); retryAnkiTask?.cancel(); selectedAnkiCard = nil }
        .task(id: query) {
            guard !query.isEmpty else {
                await model.updateResults(for: query)
                return
            }
            // Небольшая пауза склеивает быстрые нажатия в один поиск.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await model.updateResults(for: query)
        }
        .sheet(item: $coordinator.selectedLinkedKanjiCard, onDismiss: {
            coordinator.closeLinkedKanjiPreview()
        }) { card in
            kanjiPreviewDetail(for: card)
        }
        .sheet(item: $coordinator.selectedLinkedWordCard, onDismiss: {
            coordinator.closeLinkedWordPreview()
        }) { word in
            linkedWordPreviewDetail(for: word)
        }
        .sheet(item: $coordinator.presentedKanaPreview, onDismiss: {
            coordinator.closeKanaPreview()
        }) { presented in
            if let card = coordinator.catalog.kana(presented.cardID), let deck = kanaDeck(for: card) {
                kanaPreviewDetail(for: card, deck: deck)
            }
        }
        .alert("Карточка Anki", isPresented: Binding(
            get: { model.openingError != nil },
            set: { if !$0 { model.openingError = nil } }
        )) {
            Button("OK") { model.openingError = nil }
        } message: { Text(model.openingError ?? "") }
        .sheet(item: $selectedGrammarRule) { rule in
            NavigationStack {
                GrammarRuleView(ruleID: rule.id, settings: settings, progress: reviewStore, translationState: translationState) { selected in
                    selectedGrammarRule = nil
                    dismiss()
                    onPractice(.grammar(selected.level, ruleID: selected.id))
                }
                .toolbar { Button("Закрыть") { selectedGrammarRule = nil } }
            }
        }
        .sheet(item: $selectedAnkiCard, onDismiss: { model.closeAnkiPreview() }) { card in
            let deck = ankiDeck(for: card)
            AnkiCardPreviewView(
                cards: [],
                initialCard: card,
                translationState: translationState,
                language: settings.options(for: deck.id).meaningLanguage,
                searchRecords: model.ankiResults,
                loadSearchCard: { try await model.resolveAnkiResult($0) }
            ) { selected in
                selectedAnkiCard = nil
                onPractice(.anki(ankiDeck(for: selected), [selected], guided: true))
            }
        }
    }

    // MARK: Шапка и поле

    private var subtitle: String {
        switch model.scope {
        case .all: "Кандзи, слова, кана, Anki и грамматика"
        case .kanji: "Все кандзи, все колоды"
        case .words: "Все слова, все уровни частотности"
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppPalette.secondaryText)

            TextField(searchPlaceholder, text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .accessibilityIdentifier(AccessibilityID.Search.field)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .foregroundStyle(AppPalette.mutedText)
                .accessibilityLabel("Очистить поиск")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .appSurfaceCard()
    }

    private var resultSummary: some View {
        Text(query.isEmpty ? "Начните вводить запрос" : resultSummaryText)
            .font(.caption)
            .foregroundStyle(AppPalette.secondaryText)
            .accessibilityIdentifier(AccessibilityID.Search.summary)
    }

    private var resultSummaryText: String {
        var text = "Найдено: \(model.totalFound)"
        if hasTruncatedSection {
            text += " (до \(CardSearchViewModel.resultLimit) в каждом разделе)"
        }
        return text
    }

    // MARK: Сетка

    @ViewBuilder
    private var resultContent: some View {
        if model.scope == .all {
            VStack(alignment: .leading, spacing: 18) {
                resultSection("Кандзи", count: model.kanjiResults.count, columns: kanjiColumns) {
                    ForEach(model.kanjiResults) { card in
                        kanjiPreviewTile(for: card, accessibilityIdentifier: AccessibilityID.Search.result) { coordinator.openLinkedKanjiPreview(card) }
                    }
                }
                resultSection("Слова", count: model.wordResults.count, columns: standardColumns) {
                    ForEach(model.wordResults) { card in
                        wordPreviewTile(for: card, accessibilityIdentifier: AccessibilityID.Search.result) { coordinator.openLinkedWordPreview(card) }
                    }
                }
                resultSection("Кана", count: model.kanaResults.count, columns: kanaColumns) {
                    ForEach(model.kanaResults) { card in
                        kanaPreviewTile(for: card, accessibilityIdentifier: AccessibilityID.Search.result)
                    }
                }
                resultSection("Грамматика", count: model.grammarResults.count, columns: standardColumns) {
                    ForEach(model.grammarResults) { rule in
                        Button { selectedGrammarRule = rule } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(rule.level.rawValue) · \(rule.pattern)").font(.headline)
                                Text(rule.displayedMeaning).font(.caption)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(12).appSurfaceCard()
                        }.buttonStyle(.plain).accessibilityIdentifier("grammar.searchResult.\(rule.id)")
                    }
                }
                resultSection("Anki", count: model.ankiResults.count, columns: standardColumns) {
                    ForEach(model.ankiResults) { card in ankiResultTile(for: card) }
                }
            }
        } else {
            LazyVGrid(columns: resultColumns, spacing: 10) {
                ForEach(model.kanjiResults) { card in
                    kanjiPreviewTile(for: card, accessibilityIdentifier: AccessibilityID.Search.result) { coordinator.openLinkedKanjiPreview(card) }
                }
                ForEach(model.wordResults) { card in
                    wordPreviewTile(for: card, accessibilityIdentifier: AccessibilityID.Search.result) { coordinator.openLinkedWordPreview(card) }
                }
            }
        }
    }

    @ViewBuilder
    private func resultSection<Content: View>(
        _ title: String,
        count: Int,
        columns: [GridItem],
        @ViewBuilder content: () -> Content
    ) -> some View {
        if count > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline).foregroundStyle(AppPalette.secondaryText)
                LazyVGrid(columns: columns, spacing: 10, content: content)
            }
        }
    }

    private func ankiResultTile(for card: AnkiSearchRecord) -> some View {
        Button {
            openingAnkiTask?.cancel()
            openingAnkiTask = Task {
                let resolved = await model.openAnkiResult(card)
                guard !Task.isCancelled else { return }
                selectedAnkiCard = resolved
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.displayTitle(using: fieldPreferences.options(
                    for: card.fieldPreferencesKey,
                    fieldCount: card.titleFields.count
                )))
                    .font(.headline)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(card.deckName).font(.caption).foregroundStyle(AppPalette.secondaryText).lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            .appSurfaceCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Search.result)
    }

    private func kanaDeck(for card: KanaStudyCard) -> KanaDeck? {
        card.script
    }

    private func ankiDeck(for card: AnkiStudyCard) -> AnkiDeckReference {
        AnkiDeckReference(
            importID: card.importID,
            sourceDeckID: card.card.deckID,
            title: card.deckName,
            cardCount: model.ankiResults.filter { $0.deckID == card.card.deckID && $0.importID == card.importID }.count
        )
    }

    private var searchPlaceholder: String {
        switch model.scope {
        case .all: "Символ, слово, чтение или значение"
        case .kanji: "Кандзи, значение или чтение"
        case .words: "Слово, чтение или значение"
        }
    }

    private var hasTruncatedSection: Bool {
        model.totalFound > model.kanjiResults.count + model.wordResults.count
            + model.kanaResults.count + model.ankiResults.count + model.grammarResults.count
    }

    private var standardColumns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 10), count: 2) }
    private var kanjiColumns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 10), count: 4) }
    private var kanaColumns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 8), count: 5) }

    private var resultColumns: [GridItem] {
        let column = GridItem(.flexible(), spacing: 10)
        return model.scope == .kanji ? Array(repeating: column, count: 4) : Array(repeating: column, count: 2)
    }
}
