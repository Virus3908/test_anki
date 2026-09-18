import Foundation

extension StudyAppViewModel {
    func synchronizeTrainingRoute() {
        if case .training = navigation.route, !trainingSession.isActive {
            navigation.finishTraining()
            coordinator.resetPreviewSelection()
            if trainingSession.didCompleteToday {
                isTodayCompletionPresented = true
            }
        }
    }

    var additionalCardsDefaultCount: Int {
        max(1, settings.options(for: navigation.route.deck?.id).dailyNewCardLimit)
    }

    func addNewCardsToToday(_ count: Int) {
        guard !isSavingReview else { return }
        guard let deckID = navigation.route.deck?.id else { return }
        trainingSession.addNewCardsToToday(count, for: deckID)
        isTodayCompletionPresented = false

        switch navigation.route {
        case .kanjiDeck:
            practice(.kanji(deckState.previewCards, guided: false))
        case .wordDeck:
            practice(.words(deckState.previewWordCards, guided: false))
        case .kanaDeck(let deck):
            practice(.kana(deck, deckState.previewKanaCards, guided: false))
        default:
            break
        }
    }
}
