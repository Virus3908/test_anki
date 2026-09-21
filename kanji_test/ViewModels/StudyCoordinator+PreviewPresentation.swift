import Foundation

extension StudyCoordinator {
    func openDeckPreview(_ deck: KanjiDeck, deckState: DeckPreviewViewModel) {
        clearDeckSelection()
        deckState.openKanjiPreview(deck)
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

    func openLinkedWordPreview(_ card: WordStudyCard) {
        selectedLinkedWordCard = card
    }

    func openLinkedWordKanjiPreview(_ card: KanjiCard) {
        selectedLinkedWordKanjiCard = card
    }

    func relatedWords(for card: KanjiCard) -> [WordStudyCard] {
        catalog.words(containing: card.kanji)
    }

    func allRelatedWords(for card: KanjiCard) -> [WordStudyCard] {
        (allRelatedWordIDsByKanji[card.id] ?? []).compactMap(catalog.word)
    }

    func openRelatedWordsList(for card: KanjiCard) {
        selectedRelatedWordsKanjiCard = card
    }

    func openRelatedWordsListWord(_ card: WordStudyCard) {
        selectedRelatedWordsListWordCard = card
    }

    func loadRelatedWords(for card: KanjiCard, force: Bool = false) async {
        let id = card.id
        guard !loadingRelatedWords.contains(id), force || !loadedRelatedWords.contains(id) else { return }

        loadingRelatedWords.insert(id)
        relatedWordLoadErrors.remove(id)
        defer { loadingRelatedWords.remove(id) }

        do {
            let words = try await WordDataLoader.loadWords(containing: card.kanji, provider: kanjiProvider)
            guard !Task.isCancelled else { return }
            catalog.register(words)
            loadedRelatedWords.insert(id)
        } catch is CancellationError {
            return
        } catch {
            relatedWordLoadErrors.insert(id)
        }
    }

    func loadAllRelatedWords(for card: KanjiCard, force: Bool = false) async {
        let id = card.id
        guard !loadingAllRelatedWords.contains(id), force || !loadedAllRelatedWords.contains(id) else { return }

        loadingAllRelatedWords.insert(id)
        allRelatedWordLoadErrors.remove(id)
        defer { loadingAllRelatedWords.remove(id) }

        do {
            let words = try await WordDataLoader.loadWords(
                containing: card.kanji,
                limit: nil,
                provider: kanjiProvider
            )
            guard !Task.isCancelled else { return }
            catalog.register(words)
            allRelatedWordIDsByKanji[id] = words.map(\.id)
            loadedAllRelatedWords.insert(id)
        } catch is CancellationError {
            return
        } catch {
            allRelatedWordLoadErrors.insert(id)
        }
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
        closeLinkedWordPreview()
        closeRelatedWordsList()
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

    func closeLinkedWordPreview() {
        selectedLinkedWordCard = nil
        closeLinkedWordKanjiPreview()
    }

    func closeLinkedWordKanjiPreview() {
        selectedLinkedWordKanjiCard = nil
    }

    func closeRelatedWordsList() {
        selectedRelatedWordsKanjiCard = nil
        closeRelatedWordsListWord()
    }

    func closeRelatedWordsListWord() {
        selectedRelatedWordsListWordCard = nil
    }

    func clearRelatedWordState() {
        loadingRelatedWords.removeAll()
        loadedRelatedWords.removeAll()
        relatedWordLoadErrors.removeAll()
        loadingAllRelatedWords.removeAll()
        loadedAllRelatedWords.removeAll()
        allRelatedWordLoadErrors.removeAll()
        allRelatedWordIDsByKanji.removeAll()
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
        selectedLinkedWordCard = nil
        selectedLinkedWordKanjiCard = nil
        selectedRelatedWordsKanjiCard = nil
        selectedRelatedWordsListWordCard = nil
        previewSwipeDirection = 0
        isDeckSchedulePresented = false
    }
}
