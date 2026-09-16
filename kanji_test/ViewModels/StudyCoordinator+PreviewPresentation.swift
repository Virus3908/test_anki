import Foundation

extension StudyCoordinator {
    func openDeckPreview(_ deck: KanjiDeck, deckState: DeckPreviewViewModel, reviewStore: KanjiReviewStore) {
        clearDeckSelection()
        deckState.openKanjiPreview(deck, reviewStore: reviewStore)
    }

    func closeDeckPreview(deckState: DeckPreviewViewModel) {
        deckState.closeKanjiPreview()
        closeKanjiPreview()
        closeDeckSchedule()
    }

    func openKanaPreview(
        _ deck: KanaDeck,
        deckState: DeckPreviewViewModel,
        trainingSession: TrainingSessionViewModel
    ) {
        selectedKanaDeck = deck
        clearDeckSelection()
        deckState.openKanaPreview(deck)
        trainingSession.resetCurrentAnswer()
    }

    func closeKanaPreview(deckState: DeckPreviewViewModel, trainingSession: TrainingSessionViewModel) {
        deckState.closeKanaPreview()
        closeKanaPreview()
        trainingSession.resetCurrentAnswer()
    }

    func openWordPreview(_ deck: WordFrequencyDeck, deckState: DeckPreviewViewModel) {
        guard !deckState.isLoadingDeck else {
            return
        }

        selectedWordDeck = deck
        clearDeckSelection()
        deckState.openWordPreview(deck)
    }

    func closeWordPreview(deckState: DeckPreviewViewModel, trainingSession: TrainingSessionViewModel) {
        deckState.closeWordPreview()
        closeWordPreview()
        trainingSession.resetCurrentAnswer()
    }

    func openKanjiPreviewCard(_ card: KanjiCard) {
        showKanjiPreview(card, swipeDirection: 0)
    }

    func openKanaPreviewCard(_ card: KanaStudyCard) {
        showKanaPreview(card, swipeDirection: 0)
    }

    func openWordPreviewCard(_ card: WordStudyCard) {
        showWordPreview(card, swipeDirection: 0)
    }

    func openLinkedKanjiPreview(_ card: KanjiCard) {
        selectedLinkedKanjiCard = card
    }

    func showKanjiPreview(_ card: KanjiCard, swipeDirection: Int) {
        selectedPreviewCard = card
        previewSwipeDirection = swipeDirection
        presentedKanjiPreview = PresentedKanjiPreview(card: card)
    }

    func showKanaPreview(_ card: KanaStudyCard, swipeDirection: Int) {
        selectedKanaPreviewCard = card
        previewSwipeDirection = swipeDirection
        presentedKanaPreview = PresentedKanaPreview(card: card)
    }

    func showWordPreview(_ card: WordStudyCard, swipeDirection: Int) {
        selectedWordPreviewCard = card
        previewSwipeDirection = swipeDirection
        presentedWordPreview = PresentedWordPreview(card: card)
    }

    func closeKanjiPreview() {
        selectedPreviewCard = nil
        presentedKanjiPreview = nil
        previewSwipeDirection = 0
    }

    func closeKanaPreview() {
        selectedKanaPreviewCard = nil
        presentedKanaPreview = nil
        previewSwipeDirection = 0
    }

    func closeWordPreview() {
        selectedWordPreviewCard = nil
        presentedWordPreview = nil
        closeLinkedKanjiPreview()
        previewSwipeDirection = 0
    }

    func closeLinkedKanjiPreview() {
        selectedLinkedKanjiCard = nil
    }

    func closeDeckSchedule() {
        isDeckSchedulePresented = false
    }

    func clearDeckSelection() {
        selectedPreviewCard = nil
        selectedKanaPreviewCard = nil
        selectedWordPreviewCard = nil
        closeDeckSchedule()
    }

    func resetPreviewSelection() {
        selectedPreviewCard = nil
        selectedKanaPreviewCard = nil
        selectedWordPreviewCard = nil
        selectedLinkedKanjiCard = nil
        presentedKanjiPreview = nil
        presentedKanaPreview = nil
        presentedWordPreview = nil
        previewSwipeDirection = 0
        isDeckSchedulePresented = false
    }
}
