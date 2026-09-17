import SwiftUI

@MainActor
protocol StudyViewStyling {}

@MainActor
protocol CardContentRendering: StudyViewStyling {
    var settings: StudyPreferences { get }
    var translationState: TranslationViewModel { get }
    var coordinator: StudyCoordinator { get }
    var reviewStore: KanjiReviewStore { get }
    var onPractice: (PracticeSelection) -> Void { get }
    var previewKanjiCards: [KanjiCard] { get }
    var previewWordCards: [WordStudyCard] { get }
    var previewKanaCards: [KanaStudyCard] { get }
}

extension CardContentRendering {
    var previewKanjiCards: [KanjiCard] { [] }
    var previewWordCards: [WordStudyCard] { [] }
    var previewKanaCards: [KanaStudyCard] { [] }
    var meaningLanguage: MeaningLanguage { settings.meaningLanguage }
    var frontFieldOrder: [FrontFieldKind] { settings.frontFieldOrder }
    var showsPromptCharacters: Bool { settings.showsPromptCharacters }
    var showsPromptReading: Bool { settings.showsPromptReading }
    var showsPromptMeaning: Bool { settings.showsPromptMeaning }
    var selectedDeck: KanjiDeck { coordinator.selectedDeck }
    var selectedWordDeck: WordFrequencyDeck { coordinator.selectedWordDeck }
    var selectedKanaDeck: KanaDeck { coordinator.selectedKanaDeck }

    func openKanjiPreviewCard(_ card: KanjiCard) { coordinator.openKanjiPreviewCard(card) }
    func openKanaPreviewCard(_ card: KanaStudyCard) { coordinator.openKanaPreviewCard(card) }
    func openWordPreviewCard(_ card: WordStudyCard) { coordinator.openWordPreviewCard(card) }
    func startTraining(with cards: [KanjiCard], guided: Bool) { onPractice(.kanji(cards, guided: guided)) }
    func startWordTraining(with cards: [WordStudyCard], guided: Bool) { onPractice(.words(cards, guided: guided)) }
    func startKanaTraining(deck: KanaDeck, cards: [KanaStudyCard], guided: Bool) { onPractice(.kana(deck, cards, guided: guided)) }
}
