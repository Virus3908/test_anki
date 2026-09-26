import SwiftUI

struct DeckPreviewView: View, CardContentRendering {
    var deckID: String? { deckState.navigation.route.deck?.id }
    let deckState: DeckPreviewViewModel
    let coordinator: StudyCoordinator
    let settings: StudyPreferences
    let translationState: TranslationViewModel
    let reviewStore: StudyProgressStore
    let session: CustomTrainingSession
    let onPractice: (PracticeSelection) -> Void
    var onCustomTraining: () -> Void = {}
    var onStartCustomTraining: () -> Void = {}
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
    /// Насколько хорошо карточка знается — по прогрессу основного обучения колоды;
    /// подсвечивает проблемные и освоенные карточки в сетке превью.
    func cardMastery(forReviewKey reviewKey: String) -> CardMastery {
        CardMastery(record: reviewStore.record(for: reviewKey),
                    isExcluded: reviewStore.isExcluded(reviewKey))
    }
    var body: some View {
        Group {
            if let deck = deckState.previewDeck { deckPreviewView(for: deck) }
            else if let deck = deckState.previewWordDeck { wordPreviewView(for: deck) }
            else if let deck = deckState.previewKanaDeck { kanaPreviewView(for: deck) }
        }
    }
    /// В режиме выбора карточек кнопка «назад» сначала выходит из выбора,
    /// а закрывает колоду только при повторном нажатии.
    func closeDeckPreview() { exitSelection { coordinator.closeDeckPreview(deckState: deckState) } }
    func closeWordPreview() { exitSelection { coordinator.closeWordPreview(deckState: deckState) } }
    func closeKanaPreview() { exitSelection { coordinator.closeKanaPreview(deckState: deckState) } }

    private func exitSelection(then close: () -> Void) {
        if session.isSelecting { session.cancelSelection() } else { close() }
    }

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
