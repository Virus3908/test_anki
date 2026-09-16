import SwiftUI

extension ContentView {
    func openKanjiPreviewCard(_ card: KanjiCard) {
        coordinator.openKanjiPreviewCard(card)
    }

    func openKanaPreviewCard(_ card: KanaStudyCard) {
        coordinator.openKanaPreviewCard(card)
    }

    func openWordPreviewCard(_ card: WordStudyCard) {
        coordinator.openWordPreviewCard(card)
    }

    func openDeckPreview(_ deck: KanjiDeck) {
        coordinator.openDeckPreview(deck, deckState: deckState, reviewStore: reviewStore)
    }

    func closeDeckPreview() {
        coordinator.closeDeckPreview(deckState: deckState)
    }

    func openKanaPreview(_ deck: KanaDeck) {
        coordinator.openKanaPreview(deck, deckState: deckState, trainingSession: trainingSession)
    }

    func closeKanaPreview() {
        coordinator.closeKanaPreview(deckState: deckState, trainingSession: trainingSession)
    }

    func openWordPreview(_ deck: WordFrequencyDeck) {
        coordinator.openWordPreview(deck, deckState: deckState)
    }

    func closeWordPreview() {
        coordinator.closeWordPreview(deckState: deckState, trainingSession: trainingSession)
    }

    func replaceCard(_ card: KanjiCard) {
        coordinator.replaceKanjiCard(card, deckState: deckState)
    }
}
