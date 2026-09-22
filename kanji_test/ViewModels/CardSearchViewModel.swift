import Foundation
import Observation

/// Экран поиска карточек: по отдельному типу или по всему каталогу приложения.
///
/// Индексы строятся один раз при первом открытии экрана (prepare); сам поиск
/// по готовому индексу — синхронный линейный проход, его можно звать на каждый
/// ввод символа. Результаты капятся до `resultLimit` с честным `totalFound`.
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
    private(set) var ankiResults: [AnkiStudyCard] = []
    /// Сколько всего нашлось (до капа на показ).
    private(set) var totalFound = 0

    let scope: Scope

    // MARK: Данные (заполняются в prepare)

    private var isPrepared = false
    private var kanjiIndex: CardSearchIndex<KanjiSearchRecord>?
    private var wordIndex: CardSearchIndex<WordSearchRecord>?
    private var kanaIndex: CardSearchIndex<KanaSearchRecord>?
    private var ankiIndex: CardSearchIndex<AnkiSearchRecord>?
    /// Кандзи по символу — для сборки карточек слов из найденных записей.
    private var cardsByCharacter: [String: KanjiCard] = [:]

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
                await prepareKana()
                if let ankiModel {
                    let cards = try await ankiModel.cardsForSearch()
                    ankiIndex = await Self.buildIndex(records: cards.map(AnkiSearchRecord.init))
                }
            case .kanji:
                try await prepareKanji()
            case .words:
                try await prepareWords()
            }

            isPrepared = true
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
        let kanjiCards = await KanjiDataLoader.loadAvailableCards(deck: .all)
        cardsByCharacter = Dictionary(
            kanjiCards.map { ($0.kanji, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        wordIndex = await Self.buildIndex(records: entries.map(WordSearchRecord.init))
    }

    private func prepareKana() async {
        let cards = KanaDeck.allCases.flatMap(\.baseCards)
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

    /// Обновляет результаты по запросу. Пустой запрос — пустые результаты.
    func updateResults(for query: String) {
        guard isPrepared else { return }

        switch scope {
        case .all:
            let foundKanji = kanjiIndex?.search(query).map(\.card) ?? []
            let foundEntries = wordIndex?.search(query).map(\.entry) ?? []
            let foundKana = kanaIndex?.search(query).map(\.card) ?? []
            let foundAnki = ankiIndex?.search(query).map(\.card) ?? []
            totalFound = foundKanji.count + foundEntries.count + foundKana.count + foundAnki.count
            kanjiResults = Array(foundKanji.prefix(Self.resultLimit))
            wordResults = WordDataLoader.buildWords(
                from: Array(foundEntries.prefix(Self.resultLimit)),
                cardsByCharacter: cardsByCharacter
            )
            kanaResults = Array(foundKana.prefix(Self.resultLimit))
            ankiResults = Array(foundAnki.prefix(Self.resultLimit))
        case .kanji:
            guard let index = kanjiIndex else { return }
            let found = index.search(query).map(\.card)
            totalFound = found.count
            kanjiResults = Array(found.prefix(Self.resultLimit))
        case .words:
            guard let index = wordIndex else { return }
            let foundEntries = index.search(query).map(\.entry)
            totalFound = foundEntries.count
            // Карточки слов собираются только для показываемого топа.
            wordResults = WordDataLoader.buildWords(
                from: Array(foundEntries.prefix(Self.resultLimit)),
                cardsByCharacter: cardsByCharacter
            )
        }
    }
}
