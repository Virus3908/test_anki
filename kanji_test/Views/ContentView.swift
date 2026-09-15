import SwiftUI

enum FrontFieldKind: String, CaseIterable, Identifiable {
    case readings
    case meanings
    case character

    var id: String { rawValue }

    var title: String {
        switch self {
        case .readings:
            return "Чтения"
        case .meanings:
            return "Значения"
        case .character:
            return "Знак"
        }
    }
}

enum MeaningLanguage: String, CaseIterable, Identifiable {
    case russian
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .russian:
            return "Русский"
        case .english:
            return "English"
        }
    }
}

struct ContentView: View {
    @State var practiceMode: PracticeMode = .kanji
    @State var deckState = DeckPreviewViewModel()
    @State var coordinator = StudyCoordinator()

    @State var trainingSession = TrainingSessionViewModel()
    @State var showsPromptCharacters = false
    @State var showsPromptReading = true
    @State var showsPromptMeaning = false
    @State var frontFieldOrder: [FrontFieldKind] = [.readings, .meanings, .character]
    @State var isSettingsPresented = false
    @State var isAboutPresented = false
    @State var translationState = TranslationViewModel()
    @AppStorage("kanjiDailyNewCardLimit") var kanjiDailyNewCardLimit = 10
    @AppStorage("kanjiLearningSuccessTarget") var kanjiLearningSuccessTarget = KanjiReviewStore.defaultLearningSuccessTarget
    @State var meaningLanguage: MeaningLanguage = .russian

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
            .navigationTitle(coordinator.hasStartedTraining ? "Kanji Trainer" : deckState.previewDeck == nil && deckState.previewKanaDeck == nil && deckState.previewWordDeck == nil ? "Набор карточек" : "Колода")
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
            .sheet(isPresented: $isSettingsPresented) {
                settingsView()
            }
            .task {
                await loadReviewMemory()
            }
        }
    }

}
