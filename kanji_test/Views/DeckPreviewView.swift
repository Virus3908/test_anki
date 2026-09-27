import SwiftUI

struct DeckPreviewView: View, CardContentRendering {
    let route: StudyRoute
    var deckID: String? { route.deck?.id }
    let deckState: DeckPreviewViewModel
    let coordinator: StudyCoordinator
    let settings: StudyPreferences
    let translationState: TranslationViewModel
    let reviewStore: StudyProgressStore
    let session: CustomTrainingSession
    let onPractice: (PracticeSelection) -> Void
    let onBack: () -> Void
    var onCustomTraining: () -> Void = {}
    var onStartCustomTraining: () -> Void = {}
    var onOpenSettings: () -> Void = {}
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
            switch route {
            case .kanjiDeck(let deck): deckPreviewView(for: deck)
            case .wordDeck(let deck): wordPreviewView(for: deck)
            case .kanaDeck(let deck): kanaPreviewView(for: deck)
            default: EmptyView()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// В режиме выбора карточек кнопка «назад» сначала выходит из выбора,
    /// а закрывает колоду только при повторном нажатии.
    func exitSelectionOrClose() {
        if session.isSelecting { session.cancelSelection() } else { onBack() }
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
