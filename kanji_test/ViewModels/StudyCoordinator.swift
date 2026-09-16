import Foundation
import Observation

struct PresentedKanjiPreview: Identifiable {
    let card: KanjiCard
    var id: String { "kanji-preview" }
}

struct PresentedKanaPreview: Identifiable {
    let card: KanaStudyCard
    var id: String { "kana-preview" }
}

struct PresentedWordPreview: Identifiable {
    let card: WordStudyCard
    var id: String { "word-preview" }
}

@Observable
final class StudyCoordinator {
    var hasStartedTraining = false
    var cards: [KanjiCard] = []
    var wordCards: [WordStudyCard] = []
    var kanaCards: [KanaStudyCard] = []
    var selectedDeck: KanjiDeck = .jlpt5
    var selectedKanaDeck: KanaDeck = .hiragana
    var selectedWordDeck: WordFrequencyDeck = .top1000
    var reviewStore = KanjiReviewStore(records: [:])
    var selectedPreviewCard: KanjiCard?
    var selectedKanaPreviewCard: KanaStudyCard?
    var selectedWordPreviewCard: WordStudyCard?
    var selectedLinkedKanjiCard: KanjiCard?
    var presentedKanjiPreview: PresentedKanjiPreview?
    var presentedKanaPreview: PresentedKanaPreview?
    var presentedWordPreview: PresentedWordPreview?
    var previewSwipeDirection = 0
    var isDeckSchedulePresented = false

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

    func mergeSelectedKanjiPreview(with card: KanjiCard) {
        guard selectedPreviewCard?.kanji == card.kanji else {
            return
        }

        selectedPreviewCard = selectedPreviewCard?.mergedForDisplay(with: card)
    }

    func mergeLinkedKanjiPreview(with card: KanjiCard) {
        guard selectedLinkedKanjiCard?.kanji == card.kanji else {
            return
        }

        selectedLinkedKanjiCard = selectedLinkedKanjiCard?.mergedForDisplay(with: card)
    }

    func replaceSelectedWordPreview(_ card: WordStudyCard) {
        selectedWordPreviewCard = card
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
