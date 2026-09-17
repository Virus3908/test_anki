import SwiftUI

struct DeckPreviewView: View, CardContentRendering {
    let deckState: DeckPreviewViewModel
    let coordinator: StudyCoordinator
    let settings: StudyPreferences
    let translationState: TranslationViewModel
    let reviewStore: KanjiReviewStore
    let onPractice: (PracticeSelection) -> Void
    var previewKanjiCards: [KanjiCard] { deckState.previewCards }
    var previewWordCards: [WordStudyCard] { deckState.previewWordCards }
    var previewKanaCards: [KanaStudyCard] { deckState.previewKanaCards }
    var body: some View {
        Group {
            if let deck = deckState.previewDeck { deckPreviewView(for: deck) }
            else if let deck = deckState.previewWordDeck { wordPreviewView(for: deck) }
            else if let deck = deckState.previewKanaDeck { kanaPreviewView(for: deck) }
        }
    }
    func closeDeckPreview() { coordinator.closeDeckPreview(deckState: deckState) }
    func closeWordPreview() { coordinator.closeWordPreview(deckState: deckState) }
    func closeKanaPreview() { coordinator.closeKanaPreview(deckState: deckState) }
}
