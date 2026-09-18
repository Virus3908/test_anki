import Foundation

extension StudyCoordinator {
    func openDeckPreview(_ deck: KanjiDeck, deckState: DeckPreviewViewModel, reviewStore: StudyProgressStore) {
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
        deckState: DeckPreviewViewModel
    ) {
        clearDeckSelection()
        deckState.openKanaPreview(deck)
    }

    func closeKanaPreview(deckState: DeckPreviewViewModel) {
        deckState.closeKanaPreview()
        closeKanaPreview()
    }

    func openWordPreview(_ deck: WordFrequencyDeck, deckState: DeckPreviewViewModel) {
        guard !deckState.isLoadingDeck else {
            return
        }

        clearDeckSelection()
        deckState.openWordPreview(deck)
    }

    func closeWordPreview(deckState: DeckPreviewViewModel) {
        deckState.closeWordPreview()
        closeWordPreview()
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
    }

    func showKanaPreview(_ card: KanaStudyCard, swipeDirection: Int) {
        selectedKanaPreviewCard = card
        previewSwipeDirection = swipeDirection
    }

    func showWordPreview(_ card: WordStudyCard, swipeDirection: Int) {
        selectedWordPreviewCard = card
        previewSwipeDirection = swipeDirection
    }

    func closeKanjiPreview() {
        selectedPreviewCard = nil
        previewSwipeDirection = 0
    }

    func closeKanaPreview() {
        selectedKanaPreviewCard = nil
        previewSwipeDirection = 0
    }

    func closeWordPreview() {
        selectedWordPreviewCard = nil
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
        resetPreviewSelection()
    }

    func resetPreviewSelection() {
        selectedPreviewCard = nil
        selectedKanaPreviewCard = nil
        selectedWordPreviewCard = nil
        selectedLinkedKanjiCard = nil
        previewSwipeDirection = 0
        isDeckSchedulePresented = false
    }
}
