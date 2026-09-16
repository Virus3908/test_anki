import Foundation

extension DeckPreviewViewModel {
    var kanjiTrainingSourceCards: [KanjiCard] {
        kanjiSourceCards.isEmpty ? previewCards : kanjiSourceCards
    }

    var wordTrainingSourceCards: [WordStudyCard] {
        wordSourceCards.isEmpty ? previewWordCards : wordSourceCards
    }

    var kanaTrainingSourceCards: [KanaStudyCard] {
        kanaSourceCards.isEmpty ? previewKanaCards : kanaSourceCards
    }

    func clearTrainingSources() {
        kanjiSourceCards.removeAll()
        wordSourceCards.removeAll()
        kanaSourceCards.removeAll()
    }

    func prepareKanjiTrainingSource(_ sourceCards: [KanjiCard]) {
        cancelPreviewTask()
        kanjiSourceCards = sourceCards
        wordSourceCards.removeAll()
        kanaSourceCards.removeAll()
    }

    func prepareWordTrainingSource(_ sourceCards: [WordStudyCard]) {
        previewWordDeck = nil
        kanjiSourceCards.removeAll()
        kanaSourceCards.removeAll()
        wordSourceCards = sourceCards
        isLoadingDeck = false
    }

    func prepareKanaTrainingSource(_ sourceCards: [KanaStudyCard]) {
        previewKanaDeck = nil
        kanjiSourceCards.removeAll()
        wordSourceCards.removeAll()
        kanaSourceCards = sourceCards
    }
}
