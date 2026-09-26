import Foundation
import Observation

@MainActor
@Observable
final class StudyAppViewModel {
    var selectedPracticeMode: PracticeMode = .kanji
    var practiceMode: PracticeMode {
        get { trainingSession.mode ?? selectedPracticeMode }
        set { selectedPracticeMode = newValue }
    }
    let settings: StudyPreferences
    let errors: StorageStatus
    let catalog: StudyCardCatalog
    let navigation: StudyNavigation
    let deckState: DeckPreviewViewModel
    let coordinator: StudyCoordinator
    let trainingSession: TrainingSessionViewModel
    let translationState: TranslationViewModel
    let ankiLibrary: AnkiLibraryViewModel
    var isSettingsPresented = false
    var isTodayCompletionPresented = false
    var isLoadingSavedState = false
    var isResettingDeckProgress = false
    var hasLoadedSavedState = false
    var isSavingReview: Bool { trainingSession.isPreparingCard || isResettingDeckProgress }
    @ObservationIgnored var trainingStartTask: Task<Void, Never>?
    @ObservationIgnored var supplementalLoadTask: Task<Void, Never>?

    deinit {
        trainingStartTask?.cancel()
        supplementalLoadTask?.cancel()
    }

    init(reviewRepository: (any ReviewPersisting)? = nil,
         translationRepository: (any TranslationPersisting)? = nil,
         translator: any MeaningTranslating = SystemRussianMeaningTranslator(),
         kanjiProvider: any KanjiProviding = KanjiAPIProvider(),
         wordProvider: any WordExampleProviding = TatoebaWordExampleProvider(),
         ankiRepository: any AnkiLibraryPersisting = AnkiRepository()) {
        let errors = StorageStatus()
        let settings = StudyPreferences(errors: errors)
        let catalog = StudyCardCatalog()
        let navigation = StudyNavigation()
        self.settings = settings
        self.errors = errors
        self.catalog = catalog
        self.navigation = navigation
        self.trainingSession = TrainingSessionViewModel(repository: reviewRepository ?? ReviewRepository(), catalog: catalog, settings: settings, errors: errors)
        self.deckState = DeckPreviewViewModel(catalog: catalog, navigation: navigation, kanjiProvider: kanjiProvider)
        self.coordinator = StudyCoordinator(catalog: catalog, navigation: navigation, kanjiProvider: kanjiProvider)
        self.ankiLibrary = AnkiLibraryViewModel(repository: ankiRepository)
        self.translationState = TranslationViewModel(repository: translationRepository ?? TranslationRepository(), translator: translator,
            kanjiProvider: kanjiProvider, wordProvider: wordProvider, errors: errors)
        self.ankiLibrary.bootstrapScheduling = { [weak trainingSession] collection, importID in
            try await trainingSession?.bootstrapAnkiHistory(collection, importID: importID)
        }
    }

    var navigationTitle: String {
        switch navigation.route {
        case .start: return "Набор карточек"
        case .training: return "Kanji Trainer"
        default: return "Колода"
        }
    }
}
