import Foundation

extension StudyAppViewModel {
    func openDeck(_ route: StudyRoute) {
        guard !isSavingReview, !deckState.isLoadingDeck else { return }
        switch route {
        case .kanjiDeck(let deck): coordinator.openDeckPreview(deck, deckState: deckState, reviewStore: trainingSession.reviewStore)
        case .wordDeck(let deck): coordinator.openWordPreview(deck, deckState: deckState)
        case .kanaDeck(let deck): coordinator.openKanaPreview(deck, deckState: deckState)
        case .ankiDeck(let deck):
            deckState.cancelPreviewTask()
            selectedPracticeMode = .anki
            navigation.route = route
            Task { await ankiLibrary.openDeck(deck) }
        default: break
        }
    }
    func practice(_ selection: PracticeSelection) {
        switch selection {
        case .kanji(let cards, let guided): startTraining(with: cards, guided: guided)
        case .words(let cards, let guided): startWordTraining(with: cards, guided: guided)
        case .kana(let deck, let cards, let guided): startKanaTraining(deck: deck, cards: cards, guided: guided)
        case .anki(let deck, let cards, let guided): startAnkiTraining(deck: deck, cards: cards, guided: guided)
        }
    }
}
