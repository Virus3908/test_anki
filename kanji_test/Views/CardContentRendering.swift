import SwiftUI

@MainActor
protocol StudyViewStyling {}

@MainActor
protocol CardContentRendering: StudyViewStyling {
    var settings: StudyPreferences { get }
    var deckID: String? { get }
    var translationState: TranslationViewModel { get }
    var coordinator: StudyCoordinator { get }
    var reviewStore: StudyProgressStore { get }
    var onPractice: (PracticeSelection) -> Void { get }
    var previewKanjiCards: [KanjiCard] { get }
    var previewWordCards: [WordStudyCard] { get }
    var previewKanaCards: [KanaStudyCard] { get }
}

extension CardContentRendering {
    var previewKanjiCards: [KanjiCard] { [] }
    var previewWordCards: [WordStudyCard] { [] }
    var previewKanaCards: [KanaStudyCard] { [] }
    var displayOptions: DeckOptions { settings.options(for: deckID) }
    var meaningLanguage: MeaningLanguage { displayOptions.meaningLanguage }
    var frontFieldOrder: [FrontFieldKind] { displayOptions.frontFieldOrder }
    var showsPromptCharacters: Bool { displayOptions.showsPromptCharacters }
    var showsPromptReading: Bool { displayOptions.showsPromptReading }
    var showsPromptMeaning: Bool { displayOptions.showsPromptMeaning }
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
