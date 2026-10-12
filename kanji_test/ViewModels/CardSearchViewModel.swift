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

    nonisolated private struct SearchResults: Sendable {
        let kanji: CardSearchMatches<KanjiSearchRecord>?
        let words: CardSearchMatches<WordSearchRecord>?
        let kana: CardSearchMatches<KanaSearchRecord>?
        let anki: CardSearchMatches<AnkiSearchRecord>?
    }

    // MARK: Данные (заполняются в prepare)

    private var isPrepared = false
    private var kanjiIndex: CardSearchIndex<KanjiSearchRecord>?
    private var wordIndex: CardSearchIndex<WordSearchRecord>?
    private var kanaIndex: CardSearchIndex<KanaSearchRecord>?
    private var ankiIndex: CardSearchIndex<AnkiSearchRecord>?
    /// Кандзи по символу — для сборки карточек слов из найденных записей.

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
        guard !isPrepared, !isPreparing else { return }
        isPreparing = true
        loadError = nil
        defer { isPreparing = false }

        do {
            switch scope {
            case .all:
                try await prepareKanji()
                try await prepareWords()
                try await prepareKana()
                if let ankiModel {
                    let records = try await ankiModel.recordsForSearch()
                    ankiIndex = await Self.buildIndex(records: records)
                }
            case .kanji:
                try await prepareKanji()
            case .words:
                try await prepareWords()
            }

            try Task.checkCancellation()
            isPrepared = true
        } catch is CancellationError {
            return
        } catch {
            loadError = "Не удалось подготовить поиск."
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
        wordIndex = await Self.buildIndex(records: entries.map(WordSearchRecord.init))
    }

    private func prepareKana() async throws {
        let cards = try await KanaDataLoader.loadAllCards()
        kanaIndex = await Self.buildIndex(records: cards.map(KanaSearchRecord.init))
    }

    /// Извлечение термов соблюдает isolation моделей, а тяжёлая склейка и
    /// lowercase выполняются в фоне.
    private static func buildIndex<Record: CardSearchRecord>(records: [Record]) async -> CardSearchIndex<Record> {
        let terms = records.map(\.searchTerms)
        return await Task.detached(priority: .userInitiated) {
            let haystacks = terms.map { $0.joined(separator: " ").lowercased() }
            return CardSearchIndex(records: records, haystacks: haystacks)
        }.value
    }

    // MARK: Поиск

    func openAnkiResult(_ record: AnkiSearchRecord) async -> AnkiStudyCard? {
        do {
            let card = try await ankiModel?.cardForSearchResult(record)
            try Task.checkCancellation()
            return card
        } catch is CancellationError { return nil }
        catch { loadError = "Не удалось открыть карточку Anki."; return nil }
    }

    /// Invalidate immediately on input changes, before the view's debounce ends.
    func cancelSearch() {
        generation += 1
        searchTask?.cancel()
        searchTask = nil
    }

    func updateResults(for query: String) async {
        cancelSearch()
        let request = generation
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            kanjiResults = []; wordResults = []; kanaResults = []; ankiResults = []
            totalFound = 0
            return
        }
        guard isPrepared, !Task.isCancelled else { return }
        let kanji = kanjiIndex, words = wordIndex, kana = kanaIndex, anki = ankiIndex
        let limit = Self.resultLimit
        let worker = Task.detached(priority: .userInitiated) {
            try SearchResults(
                kanji: kanji?.search(query, limit: limit),
                words: words?.search(query, limit: limit),
                kana: kana?.search(query, limit: limit),
                anki: anki?.search(query, limit: limit)
            )
        }
        searchTask = worker
        do {
            let found = try await withTaskCancellationHandler {
                try await worker.value
            } onCancel: { worker.cancel() }
            guard generation == request, !Task.isCancelled else { return }
            let entries = found.words?.records.map(\.entry) ?? []
            let cards = await WordDataLoader.loadKanjiCards(for: entries, provider: KanjiAPIProvider())
            guard generation == request, !Task.isCancelled else { return }
            kanjiResults = found.kanji?.records.map(\.card) ?? []
            wordResults = WordDataLoader.buildWords(from: entries,
                cardsByCharacter: Dictionary(cards.map { ($0.kanji, $0) }, uniquingKeysWith: { first, _ in first }))
            kanaResults = found.kana?.records.map(\.card) ?? []
            ankiResults = found.anki?.records ?? []
            totalFound = (found.kanji?.totalFound ?? 0) + (found.words?.totalFound ?? 0)
                + (found.kana?.totalFound ?? 0) + (found.anki?.totalFound ?? 0)
            searchTask = nil
        } catch is CancellationError {
            // A cancelled query must never publish partial results.
        } catch {
            if generation == request { loadError = "Не удалось выполнить поиск." }
        }
    }
}
