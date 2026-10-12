import Foundation
import Observation

/// Экран поиска карточек: по отдельному типу или по всему каталогу приложения.
///
/// Индексы строятся один раз при первом открытии экрана (prepare); сам поиск
/// по готовому индексу выполняется отменяемой фоновой задачей. Результаты капятся до `resultLimit` с честным `totalFound`.
@MainActor
@Observable
final class CardSearchViewModel {
    /// Что ищем. Задаётся снаружи — тем местом, которое открыло поиск:
    /// шапка колоды кандзи → .kanji, шапка колоды слов → .words.
    enum Scope {
        case all
        case kanji
        case words
    }

    /// Показываем не больше этого количества тайлов; в счётчике — все.
    static let resultLimit = 60

    // MARK: Состояние

    private(set) var isPreparing = false
    private(set) var loadError: String?
    private(set) var searchError: String?
    var openingError: String?
    private(set) var unavailableAnkiImports: [AnkiImportSummary] = []
    @ObservationIgnored private let previewSession = AnkiSearchPreviewSession()
    private var openingGeneration = 0
    private var preparationGeneration = 0
    private var isClosed = false

    /// Результаты последнего запроса (заполняется массив активного scope).
    private(set) var kanjiResults: [KanjiCard] = []
    private(set) var wordResults: [WordStudyCard] = []
    private(set) var kanaResults: [KanaStudyCard] = []
    private(set) var ankiResults: [AnkiSearchRecord] = []
    /// Сколько всего нашлось (до капа на показ).
    private(set) var totalFound = 0

    let scope: Scope

    @ObservationIgnored private var searchTask: Task<SearchResults, Error>?
    private var generation = 0
    private var latestQuery = ""

    nonisolated private struct SearchResults: Sendable {
        let kanji: CardSearchMatches<KanjiSearchRecord>?
        let words: CardSearchMatches<WordSearchRecord>?
        let kana: CardSearchMatches<KanaSearchRecord>?
        let anki: CardSearchMatches<AnkiSearchRecord>?
        let wordCards: [WordStudyCard]
    }

    // MARK: Данные (заполняются в prepare)

    private var isPrepared = false
    private var kanjiIndex: CardSearchIndex<KanjiSearchRecord>?
    private var wordIndex: CardSearchIndex<WordSearchRecord>?
    private var kanaIndex: CardSearchIndex<KanaSearchRecord>?
    private var ankiIndex: CardSearchIndex<AnkiSearchRecord>?

    /// Переводы: из них берутся сохранённые рус. значения кандзи.
    private let translationState: TranslationViewModel
    private let ankiModel: AnkiLibraryViewModel?

    init(scope: Scope, translationState: TranslationViewModel, ankiModel: AnkiLibraryViewModel? = nil) {
        self.scope = scope
        self.translationState = translationState
        self.ankiModel = ankiModel
    }

    // MARK: Подготовка

    /// Строит индекс по активному scope. Повторный вызов — мгновенный выход.
    func prepare() async {
        isClosed = false
        if isPrepared { loadError = nil; return }
        guard !isPreparing else { return }
        isPreparing = true
        preparationGeneration += 1
        let token = preparationGeneration
        loadError = nil
        defer { if preparationGeneration == token { isPreparing = false } }

        do {
            switch scope {
            case .all:
                try await prepareKanji()
                try Task.checkCancellation()
                try await prepareWords()
                try Task.checkCancellation()
                try await prepareKana()
                try Task.checkCancellation()
                if let ankiModel {
                    let records = try await ankiModel.recordsForSearch()
                    guard !isClosed, preparationGeneration == token else { return }
                    unavailableAnkiImports = ankiModel.searchUnavailableImports
                    ankiIndex = await Self.buildIndex(records: records)
                }
            case .kanji:
                try await prepareKanji()
            case .words:
                try await prepareWords()
            }

            try Task.checkCancellation()
            guard !isClosed, preparationGeneration == token else { return }
            isPrepared = true
        } catch is CancellationError {
            return
        } catch {
            if !isClosed, !Task.isCancelled, preparationGeneration == token { loadError = "Не удалось подготовить поиск." }
        }
    }

    private func prepareKanji() async throws {
        let cards = await KanjiDataLoader.loadAvailableCards(deck: .all)
        let records = cards.map { card in
            KanjiSearchRecord(
                card: card,
                russianMeanings: translationState.displayedKanjiMeanings(for: card, language: .russian)
            )
        }
        kanjiIndex = await Self.buildIndex(records: records)
    }

    private func prepareWords() async throws {
        let entries = try await WordDataLoader.loadDictionaryEntries()
        let worker = Task.detached(priority: .userInitiated) {
            CardSearchIndex(records: entries.map(WordSearchRecord.init))
        }
        wordIndex = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
    }

    private func prepareKana() async throws {
        let cards = try await KanaDataLoader.loadAllCards()
        kanaIndex = await Self.buildIndex(records: cards.map(KanaSearchRecord.init))
    }

    /// Sendable records can be normalized entirely outside MainActor.
    private static func buildIndex<Record: CardSearchRecord>(records: [Record]) async -> CardSearchIndex<Record> {
        let worker = Task.detached(priority: .userInitiated) { CardSearchIndex(records: records) }
        return await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
    }

    // MARK: Поиск

    func resolveAnkiResult(_ record: AnkiSearchRecord) async throws -> AnkiStudyCard {
        guard let ankiModel else { throw CocoaError(.fileReadNoSuchFile) }
        guard !isClosed else { throw CancellationError() }
        let card = try await ankiModel.cardForSearchResult(record, session: previewSession)
        try Task.checkCancellation()
        guard !isClosed else { throw CancellationError() }
        return card
    }

    func openAnkiResult(_ record: AnkiSearchRecord) async -> AnkiStudyCard? {
        openingGeneration += 1
        let token = openingGeneration
        openingError = nil
        do {
            let card = try await resolveAnkiResult(record)
            try Task.checkCancellation()
            guard !isClosed, token == openingGeneration else { return nil }
            return card
        } catch is CancellationError { return nil }
        catch {
            if !isClosed, !Task.isCancelled, token == openingGeneration {
                openingError = "Не удалось открыть карточку Anki."
            }
            return nil
        }
    }

    func closeAnkiPreview() {
        openingGeneration += 1
        openingError = nil
        previewSession.close()
    }

    func close() {
        isClosed = true
        preparationGeneration += 1
        isPreparing = false
        cancelSearch()
        closeAnkiPreview()
    }

    func retryAnkiSearch() async {
        guard let ankiModel, !isClosed else { return }
        preparationGeneration += 1
        let token = preparationGeneration
        do {
            let records = try await ankiModel.recordsForSearch()
            let index = await Self.buildIndex(records: records)
            try Task.checkCancellation()
            guard !isClosed, token == preparationGeneration else { return }
            ankiIndex = index
            unavailableAnkiImports = ankiModel.searchUnavailableImports
            await updateResults(for: latestQuery)
        } catch is CancellationError { }
        catch {
            if !isClosed, token == preparationGeneration { searchError = "Не удалось обновить поиск Anki." }
        }
    }

    func queryChanged(to query: String) {
        latestQuery = query
        cancelSearch()
    }

    /// Invalidate immediately on input changes, before the view's debounce ends.
    func cancelSearch() {
        generation += 1
        searchTask?.cancel()
        searchTask = nil
    }

    func updateResults(for query: String) async {
        latestQuery = query
        cancelSearch()
        searchError = nil
        let request = generation
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            kanjiResults = []; wordResults = []; kanaResults = []; ankiResults = []
            totalFound = 0
            return
        }
        guard isPrepared, !isClosed, !Task.isCancelled else { return }
        let kanji = kanjiIndex, words = wordIndex, kana = kanaIndex, anki = ankiIndex
        let limit = Self.resultLimit
        let worker = Task.detached(priority: .userInitiated) {
            let foundKanji = try kanji?.search(query, limit: limit)
            let foundWords = try words?.search(query, limit: limit)
            let foundKana = try kana?.search(query, limit: limit)
            let foundAnki = try anki?.search(query, limit: limit)
            let entries = foundWords?.records.map(\.entry) ?? []
            let characters = WordDataLoader.requiredKanjiCharacters(in: entries)
            let cards = (try? await BundledStudyData.shared.bundledKanjiCards(characters: characters)) ?? []
            try Task.checkCancellation()
            let wordCards = WordDataLoader.buildWords(from: entries,
                cardsByCharacter: Dictionary(cards.map { ($0.kanji, $0) }, uniquingKeysWith: { first, _ in first }))
            try Task.checkCancellation()
            return SearchResults(kanji: foundKanji, words: foundWords,
                                 kana: foundKana, anki: foundAnki, wordCards: wordCards)
        }
        searchTask = worker
        do {
            let found = try await withTaskCancellationHandler {
                try await worker.value
            } onCancel: { worker.cancel() }
            guard generation == request, !Task.isCancelled else { return }
            kanjiResults = found.kanji?.records.map(\.card) ?? []
            wordResults = found.wordCards
            kanaResults = found.kana?.records.map(\.card) ?? []
            ankiResults = found.anki?.records ?? []
            totalFound = (found.kanji?.totalFound ?? 0) + (found.words?.totalFound ?? 0)
                + (found.kana?.totalFound ?? 0) + (found.anki?.totalFound ?? 0)
            searchTask = nil
        } catch is CancellationError {
            // A cancelled query must never publish partial results.
        } catch {
            if generation == request, !isClosed, !Task.isCancelled { searchError = "Не удалось выполнить поиск." }
        }
    }
}
