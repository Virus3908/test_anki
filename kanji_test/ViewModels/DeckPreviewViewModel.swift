import Foundation

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
}
