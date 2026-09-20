import Foundation
import Observation

/// Экран поиска карточек: по всем кандзи или по всем словам.
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
    /// Сколько всего нашлось (до капа на показ).
    private(set) var totalFound = 0

    let scope: Scope

    // MARK: Данные (заполняются в prepare)

    private var isPrepared = false
    private var kanjiIndex: CardSearchIndex<KanjiSearchRecord>?
    private var wordIndex: CardSearchIndex<WordSearchRecord>?
    /// Кандзи по символу — для сборки карточек слов из найденных записей.
    private var cardsByCharacter: [String: KanjiCard] = [:]

    /// Переводы: из них берутся сохранённые рус. значения кандзи.
    private let translationState: TranslationViewModel

    init(scope: Scope, translationState: TranslationViewModel) {
        self.scope = scope
        self.translationState = translationState
    }

    // MARK: Подготовка

    /// Строит индекс по активному scope. Повторный вызов — мгновенный выход.
    func prepare() async {
        guard !isPrepared, !isPreparing else { return }
        isPreparing = true
        defer { isPreparing = false }

        do {
            switch scope {
            case .kanji:
                // .all — супермножество всех колод, порядок — сортировка по кандзи.
                let cards = await KanjiDataLoader.loadAvailableCards(deck: .all)
                let records = cards.map { card in
                    // Рус. значения — из сохранённых переводов (без сети);
                    // если перевода ещё нет, вернутся англ. (дубли в haystack не мешают).
                    KanjiSearchRecord(
                        card: card,
                        russianMeanings: translationState.displayedKanjiMeanings(for: card, language: .russian)
                    )
                }
                kanjiIndex = await Self.buildIndex(records: records)
            case .words:
                // Все слова всех сабсетов частотности — это весь словарь.
                let entries = try await WordDataLoader.loadDictionaryEntries()
                let kanjiCards = await KanjiDataLoader.loadAvailableCards(deck: .all)
                cardsByCharacter = Dictionary(
                    kanjiCards.map { ($0.kanji, $0) },
                    uniquingKeysWith: { current, _ in current }
                )
                wordIndex = await Self.buildIndex(records: entries.map(WordSearchRecord.init))
            }

            isPrepared = true
        } catch {
            loadError = "Не удалось подготовить поиск."
        }
    }

    /// Тяжёлая часть подготовки (склейка и lowercase всех термов) — в фоне.
    private static func buildIndex<Record: CardSearchRecord>(records: [Record]) async -> CardSearchIndex<Record> {
        await Task.detached(priority: .userInitiated) {
            CardSearchIndex(records: records)
        }.value
    }

    // MARK: Поиск

    /// Обновляет результаты по запросу. Пустой запрос — пустые результаты.
    func updateResults(for query: String) {
        guard isPrepared else { return }

        switch scope {
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
