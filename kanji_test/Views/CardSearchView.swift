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

    @State private var model: CardSearchViewModel
    @State private var query = ""
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
            model.updateResults(for: query)
        }
        .task(id: query) {
            guard !query.isEmpty else {
                model.updateResults(for: query)
                return
            }
            // Небольшая пауза склеивает быстрые нажатия в один поиск.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            model.updateResults(for: query)
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
        .sheet(item: $selectedAnkiCard) { card in
            let deck = ankiDeck(for: card)
            AnkiCardPreviewView(
                cards: model.ankiResults,
                initialCard: card,
                translationState: translationState,
                language: settings.options(for: deck.id).meaningLanguage
            ) { selected in
                selectedAnkiCard = nil
                onPractice(.anki(deck, [selected], guided: true))
            }
        }
    }

    // MARK: Шапка и поле

    private var subtitle: String {
        switch model.scope {
        case .all: "Кандзи, слова, кана и Anki"
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

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .foregroundStyle(AppPalette.mutedText)
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
                        kanjiPreviewTile(for: card) { coordinator.openLinkedKanjiPreview(card) }
                    }
                }
                resultSection("Слова", count: model.wordResults.count, columns: standardColumns) {
                    ForEach(model.wordResults) { card in
                        wordPreviewTile(for: card) { coordinator.openLinkedWordPreview(card) }
                    }
                }
                resultSection("Кана", count: model.kanaResults.count, columns: kanaColumns) {
                    ForEach(model.kanaResults) { card in kanaPreviewTile(for: card) }
                }
                resultSection("Anki", count: model.ankiResults.count, columns: standardColumns) {
                    ForEach(model.ankiResults) { card in ankiResultTile(for: card) }
                }
            }
        } else {
            LazyVGrid(columns: resultColumns, spacing: 10) {
                ForEach(model.kanjiResults) { card in
                    kanjiPreviewTile(for: card) { coordinator.openLinkedKanjiPreview(card) }
                }
                ForEach(model.wordResults) { card in
                    wordPreviewTile(for: card) { coordinator.openLinkedWordPreview(card) }
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

    private func ankiResultTile(for card: AnkiStudyCard) -> some View {
        Button { selectedAnkiCard = card } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.displayTitle).font(.headline).lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(card.deckName).font(.caption).foregroundStyle(AppPalette.secondaryText).lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            .appSurfaceCard()
        }
        .buttonStyle(.plain)
    }

    private func kanaDeck(for card: KanaStudyCard) -> KanaDeck? {
        KanaDeck.allCases.first { deck in deck.baseCards.contains { $0.id == card.id } }
    }

    private func ankiDeck(for card: AnkiStudyCard) -> AnkiDeckReference {
        AnkiDeckReference(
            importID: card.importID,
            sourceDeckID: card.card.deckID,
            title: card.deckName,
            cardCount: model.ankiResults.filter { $0.card.deckID == card.card.deckID && $0.importID == card.importID }.count
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
            + model.kanaResults.count + model.ankiResults.count
    }

    private var standardColumns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 10), count: 2) }
    private var kanjiColumns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 10), count: 4) }
    private var kanaColumns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 8), count: 5) }

    private var resultColumns: [GridItem] {
        let column = GridItem(.flexible(), spacing: 10)
        return model.scope == .kanji ? Array(repeating: column, count: 4) : Array(repeating: column, count: 2)
    }
}
