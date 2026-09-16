import SwiftUI

extension ContentView {
    func startRandomTrainingFromPreview() {
        startTraining(with: nextKanjiSessionCards(from: deckState.previewCards), sourceCards: deckState.previewCards, guided: false)
    }

    func startTraining(with trainingCards: [KanjiCard], sourceCards: [KanjiCard]? = nil, guided: Bool) {
        practiceMode = .kanji
        coordinator.beginKanjiTraining(
            with: trainingCards,
            sourceCards: sourceCards ?? trainingCards,
            deckState: deckState,
            trainingSession: trainingSession,
            guided: guided
        )
    }

    func nextKanjiSessionCards(from sourceCards: [KanjiCard]) -> [KanjiCard] {
        nextSessionItems(from: sourceCards)
    }

    func nextWordSessionCards(from sourceCards: [WordStudyCard]) -> [WordStudyCard] {
        nextSessionItems(from: sourceCards)
    }

    func nextKanaSessionCards(from sourceCards: [KanaStudyCard]) -> [KanaStudyCard] {
        nextSessionItems(from: sourceCards)
    }

    func nextSessionItems<Item: StudyItem>(from sourceItems: [Item]) -> [Item] {
        trainingSession.nextSessionItems(
            from: sourceItems,
            reviewStore: reviewStore,
            newCardLimit: kanjiDailyNewCardLimit,
            learningSuccessTarget: kanjiLearningSuccessTarget
        )
    }

    func startWordTraining(with trainingCards: [WordStudyCard], sourceCards: [WordStudyCard]? = nil, guided: Bool = false) {
        practiceMode = .words
        coordinator.beginWordTraining(
            with: trainingCards,
            sourceCards: sourceCards ?? trainingCards,
            deckState: deckState,
            trainingSession: trainingSession,
            guided: guided
        )
    }

    func startKanaTraining(
        deck: KanaDeck,
        cards trainingCards: [KanaStudyCard]? = nil,
        sourceCards providedSourceCards: [KanaStudyCard]? = nil,
        guided: Bool = false
    ) {
        selectedKanaDeck = deck
        practiceMode = .kana
        let sourceCards = providedSourceCards ?? trainingCards ?? deck.cards
        coordinator.beginKanaTraining(
            deck: deck,
            trainingCards: trainingCards ?? nextKanaSessionCards(from: sourceCards),
            sourceCards: sourceCards,
            deckState: deckState,
            trainingSession: trainingSession,
            guided: guided
        )
    }

    func loadSelectedDeck() async {
        guard deckState.beginDeckLoad() else {
            return
        }

        let loadedCards = await KanjiDataLoader.loadCards(deck: selectedDeck)

        guard !loadedCards.isEmpty else {
            deckState.finishDeckLoad()
            return
        }

        let orderedCards = nextKanjiSessionCards(from: loadedCards)
        if practiceMode == .words {
            coordinator.beginWordTraining(
                with: WordStudyCard.build(from: loadedCards),
                sourceCards: WordStudyCard.build(from: loadedCards),
                deckState: deckState,
                trainingSession: trainingSession,
                guided: false
            )
        } else {
            coordinator.beginKanjiTraining(
                with: orderedCards,
                sourceCards: loadedCards,
                deckState: deckState,
                trainingSession: trainingSession,
                guided: false
            )
        }
        deckState.finishDeckLoad()
    }

    func beginTraining<Item: StudyItem>(with trainingItems: [Item], guided: Bool) {
        coordinator.beginTrainingSession(with: trainingItems, trainingSession: trainingSession, guided: guided)
    }
}
