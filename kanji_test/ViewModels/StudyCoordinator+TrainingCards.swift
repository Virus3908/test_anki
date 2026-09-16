import Foundation

extension StudyCoordinator {
    func useKanjiTrainingCards(_ trainingCards: [KanjiCard]) {
        cards = trainingCards
        wordCards.removeAll()
        kanaCards.removeAll()
    }

    func useWordTrainingCards(_ trainingCards: [WordStudyCard]) {
        cards.removeAll()
        wordCards = trainingCards
        kanaCards.removeAll()
    }

    func useKanaTrainingCards(_ trainingCards: [KanaStudyCard]) {
        cards.removeAll()
        wordCards.removeAll()
        kanaCards = trainingCards
    }

    func clearTrainingCards() {
        cards.removeAll()
        wordCards.removeAll()
        kanaCards.removeAll()
    }
}
