import Foundation
import Observation

@MainActor
@Observable
final class DeckPreviewViewModel {
    let catalog: StudyCardCatalog
    let navigation: StudyNavigation
    let kanjiProvider: any KanjiProviding
    var loadError: String?
    var previewRequestID = UUID()

    init(catalog: StudyCardCatalog, navigation: StudyNavigation, kanjiProvider: any KanjiProviding) {
        self.catalog = catalog
        self.navigation = navigation
        self.kanjiProvider = kanjiProvider
    }

    var previewDeck: KanjiDeck? {
        if case .kanjiDeck(let deck) = navigation.route { return deck }
        return nil
    }
    var previewKanaDeck: KanaDeck? {
        if case .kanaDeck(let deck) = navigation.route { return deck }
        return nil
    }
    var previewWordDeck: WordFrequencyDeck? {
        if case .wordDeck(let deck) = navigation.route { return deck }
        return nil
    }
    var previewExpectedCount: Int?
    private var previewKanjiIDs: [String] = []
    var previewCards: [KanjiCard] {
        get { previewKanjiIDs.compactMap { catalog.kanji($0) } }
        set { previewKanjiIDs = catalog.register(newValue) }
    }
    private var previewWordIDs: [String] = []
    var previewWordCards: [WordStudyCard] {
        get { previewWordIDs.compactMap { catalog.word($0) } }
        set { previewWordIDs = catalog.register(newValue) }
    }
    private var previewKanaIDs: [String] = []
    var previewKanaCards: [KanaStudyCard] {
        get { previewKanaIDs.compactMap { catalog.kana($0) } }
        set { previewKanaIDs = catalog.register(newValue) }
    }
    var deckPreviewTask: Task<Void, Never>?
    var isLoadingDeck = false

    func clearCacheState() {
        cancelPreviewTask()
        previewCards.removeAll()
        previewKanaCards.removeAll()
        previewWordCards.removeAll()
        previewExpectedCount = nil
        navigation.reset()
        loadError = nil
        isLoadingDeck = false
    }

    func beginDeckLoad() -> Bool {
        guard !isLoadingDeck else {
            return false
        }

        isLoadingDeck = true
        return true
    }

    func finishDeckLoad() {
        isLoadingDeck = false
    }

    func cancelPreviewTask() {
        previewRequestID = UUID()
        deckPreviewTask?.cancel()
        deckPreviewTask = nil
    }

}
