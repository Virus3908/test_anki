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

@MainActor
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
}
