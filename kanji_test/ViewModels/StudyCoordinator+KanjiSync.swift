import Foundation

extension StudyCoordinator {
    func replaceKanjiCard(_ card: KanjiCard) {
        catalog.update(card)
    }

    func latestKanjiCard(for card: KanjiCard) -> KanjiCard {
        catalog.kanji(card.id) ?? card
    }
}
