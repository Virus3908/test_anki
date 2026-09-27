import Foundation

extension StudyAppViewModel {
    func openDeck(_ route: StudyRoute) {
        guard !isSavingReview, !deckState.isLoadingDeck else { return }
        switch route {
        case .kanjiDeck(let deck): coordinator.openDeckPreview(deck, deckState: deckState)
        case .wordDeck(let deck): coordinator.openWordPreview(deck, deckState: deckState)
        case .kanaDeck(let deck): coordinator.openKanaPreview(deck, deckState: deckState)
        case .ankiDeck(let deck):
            deckState.cancelPreviewTask()
            selectedPracticeMode = .anki
            navigation.open(route)
            ankiLibrary.beginOpening(deck)
        default: break
        }
    }


    /// Единая точка очистки закрытой колоды — после pop кнопкой «назад»,
    /// системным свайпом или сбросом навигации. Если в стеке уже открыта
    /// другая колода, её открытие само сбросило состояние — не трогаем.
    func cleanUpAfterClosing(_ route: StudyRoute) {
        guard navigation.path.isEmpty else { return }
        customTraining.cancelSelection()
        coordinator.resetPreviewSelection()
        switch route {
        case .kanjiDeck: deckState.closeKanjiPreview()
        case .wordDeck: deckState.closeWordPreview()
        case .kanaDeck: deckState.closeKanaPreview()
        case .ankiDeck: ankiLibrary.closeDeck()
        case .start, .training, .customTraining: break
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
