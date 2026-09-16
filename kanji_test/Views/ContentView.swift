import SwiftUI

struct ContentView: View {
    @State var appModel = StudyAppViewModel()

    @AppStorage("kanjiDailyNewCardLimit") var kanjiDailyNewCardLimit = 10
    @AppStorage("kanjiLearningSuccessTarget") var kanjiLearningSuccessTarget = KanjiReviewStore.defaultLearningSuccessTarget

    var practiceMode: PracticeMode {
        get { appModel.practiceMode }
        nonmutating set { appModel.practiceMode = newValue }
    }

    var practiceModeBinding: Binding<PracticeMode> {
        Binding(
            get: { practiceMode },
            set: { practiceMode = $0 }
        )
    }

    var meaningLanguage: MeaningLanguage {
        get { appModel.meaningLanguage }
        nonmutating set { appModel.meaningLanguage = newValue }
    }

    var meaningLanguageBinding: Binding<MeaningLanguage> {
        Binding(
            get: { meaningLanguage },
            set: { meaningLanguage = $0 }
        )
    }

    var showsPromptCharacters: Bool {
        get { appModel.showsPromptCharacters }
        nonmutating set { appModel.showsPromptCharacters = newValue }
    }

    var showsPromptReading: Bool {
        get { appModel.showsPromptReading }
        nonmutating set { appModel.showsPromptReading = newValue }
    }

    var showsPromptMeaning: Bool {
        get { appModel.showsPromptMeaning }
        nonmutating set { appModel.showsPromptMeaning = newValue }
    }

    var frontFieldOrder: [FrontFieldKind] {
        get { appModel.frontFieldOrder }
        nonmutating set { appModel.frontFieldOrder = newValue }
    }

    var isSettingsPresented: Bool {
        get { appModel.isSettingsPresented }
        nonmutating set { appModel.isSettingsPresented = newValue }
    }

    var isSettingsPresentedBinding: Binding<Bool> {
        Binding(
            get: { isSettingsPresented },
            set: { isSettingsPresented = $0 }
        )
    }

    var isAboutPresented: Bool {
        get { appModel.isAboutPresented }
        nonmutating set { appModel.isAboutPresented = newValue }
    }

    var isAboutPresentedBinding: Binding<Bool> {
        Binding(
            get: { isAboutPresented },
            set: { isAboutPresented = $0 }
        )
    }

    var deckState: DeckPreviewViewModel {
        get { appModel.deckState }
        nonmutating set { appModel.deckState = newValue }
    }

    var coordinator: StudyCoordinator {
        get { appModel.coordinator }
        nonmutating set { appModel.coordinator = newValue }
    }

    var trainingSession: TrainingSessionViewModel {
        get { appModel.trainingSession }
        nonmutating set { appModel.trainingSession = newValue }
    }

    var drawingSession: DrawingSessionViewModel {
        trainingSession.drawingSession
    }

    var translationState: TranslationViewModel {
        get { appModel.translationState }
        nonmutating set { appModel.translationState = newValue }
    }

    var cards: [KanjiCard] {
        get { coordinator.cards }
        nonmutating set { coordinator.cards = newValue }
    }

    var wordCards: [WordStudyCard] {
        get { coordinator.wordCards }
        nonmutating set { coordinator.wordCards = newValue }
    }

    var kanaCards: [KanaStudyCard] {
        get { coordinator.kanaCards }
        nonmutating set { coordinator.kanaCards = newValue }
    }

    var selectedDeck: KanjiDeck {
        get { coordinator.selectedDeck }
        nonmutating set { coordinator.selectedDeck = newValue }
    }

    var selectedKanaDeck: KanaDeck {
        get { coordinator.selectedKanaDeck }
        nonmutating set { coordinator.selectedKanaDeck = newValue }
    }

    var selectedWordDeck: WordFrequencyDeck {
        get { coordinator.selectedWordDeck }
        nonmutating set { coordinator.selectedWordDeck = newValue }
    }

    var reviewStore: KanjiReviewStore {
        get { coordinator.reviewStore }
        nonmutating set { coordinator.reviewStore = newValue }
    }

    var body: some View {
        NavigationStack {
            Group {
                if coordinator.hasStartedTraining {
                    activeTrainingView()
                } else if let previewDeck = deckState.previewDeck {
                    deckPreviewView(for: previewDeck)
                } else if let previewKanaDeck = deckState.previewKanaDeck {
                    kanaPreviewView(for: previewKanaDeck)
                } else if let previewWordDeck = deckState.previewWordDeck {
                    wordPreviewView(for: previewWordDeck)
                } else {
                    startView()
                }
            }
            .navigationTitle(appModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppPalette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .disabled(deckState.isLoadingDeck)
                }
            }
            .sheet(isPresented: isSettingsPresentedBinding) {
                settingsView()
            }
            .task {
                await loadReviewMemory()
            }
        }
    }

}
