import Foundation
import Observation

@MainActor
@Observable
final class DeckPreviewViewModel {
    var previewDeck: KanjiDeck?
    var previewKanaDeck: KanaDeck?
    var previewWordDeck: WordFrequencyDeck?
    var previewCards: [KanjiCard] = []
    var previewKanaCards: [KanaStudyCard] = []
    var previewWordCards: [WordStudyCard] = []
    var previewExpectedCount: Int?
    var kanjiSourceCards: [KanjiCard] = []
    var wordSourceCards: [WordStudyCard] = []
    var kanaSourceCards: [KanaStudyCard] = []
    var deckPreviewTask: Task<Void, Never>?
    var isLoadingDeck = false

    func clearCacheState() {
        cancelPreviewTask()
        clearTrainingSources()
        previewCards.removeAll()
        previewKanaCards.removeAll()
        previewWordCards.removeAll()
        previewExpectedCount = nil
        previewDeck = nil
        previewKanaDeck = nil
        previewWordDeck = nil
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
        deckPreviewTask?.cancel()
        deckPreviewTask = nil
    }

}
