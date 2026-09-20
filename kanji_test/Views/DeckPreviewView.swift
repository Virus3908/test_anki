import SwiftUI

struct DeckPreviewView: View, CardContentRendering {
    var deckID: String? { deckState.navigation.route.deck?.id }
    let deckState: DeckPreviewViewModel
    let coordinator: StudyCoordinator
    let settings: StudyPreferences
    let translationState: TranslationViewModel
    let reviewStore: StudyProgressStore
    let onPractice: (PracticeSelection) -> Void
    var previewKanjiCards: [KanjiCard] { deckState.previewCards }
    var previewWordCards: [WordStudyCard] { deckState.previewWordCards }
    var previewKanaCards: [KanaStudyCard] { deckState.previewKanaCards }
    /// Открыт ли экран поиска (лупа в шапке колоды). Внутренний уровень
    /// доступа: расширения в соседних файлах используют это состояние.
    @State var isSearchPresented = false
    func previewPlan(sourceIDs: [String], deck: StudyDeck) -> StudyQueuePlan {
        TrainingSessionEngine.plan(
            sourceIDs: sourceIDs,
            mode: deck.mode,
            deckID: deck.id,
            progress: reviewStore,
            options: settings.options(for: deck.id)
        )
    }
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

    /// Лист поиска: кандзи-колода ищет по всем кандзи, словарная — по всем словам.
    func cardSearchSheet(scope: CardSearchViewModel.Scope) -> some View {
        CardSearchView(
            scope: scope,
            coordinator: coordinator,
            settings: settings,
            translationState: translationState,
            reviewStore: reviewStore,
            onPractice: onPractice
        )
    }
}
