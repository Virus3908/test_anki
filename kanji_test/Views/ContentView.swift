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

enum KanjiLearningSessionPhase {
    case review
    case learning
    case fallbackReview
}

struct ContentView: View {
    @State var practiceMode: PracticeMode = .kanji
    @State var cards: [KanjiCard] = []
    @State var wordCards: [WordStudyCard] = []
    @State var kanaCards: [KanaStudyCard] = []
    @State var selectedDeck: KanjiDeck = .jlpt5
    @State var selectedKanaDeck: KanaDeck = .hiragana
    @State var previewDeck: KanjiDeck?
    @State var previewKanaDeck: KanaDeck?
    @State var previewWordDeck: WordFrequencyDeck?
    @State var previewCards: [KanjiCard] = []
    @State var kanjiSourceCards: [KanjiCard] = []
    @State var previewKanaCards: [KanaStudyCard] = []
    @State var previewWordCards: [WordStudyCard] = []
    @State var previewExpectedCount: Int?
    @State var selectedPreviewCard: KanjiCard?
    @State var selectedKanaPreviewCard: KanaStudyCard?
    @State var selectedWordPreviewCard: WordStudyCard?
    @State var selectedLinkedKanjiCard: KanjiCard?
    @State var isPreviewDetailPresented = false
    @State var isLinkedKanjiPresented = false
    @State var previewSwipeDirection = 0
    @State var deckPreviewTask: Task<Void, Never>?
    @State var isLoadingDeck = false
    @State var isPreparingCard = false
    @State var hasStartedTraining = false
    @State var isDeckSchedulePresented = false
    @State var reviewStore = KanjiReviewStore(records: [:])

    @State var currentIndex = 0
    @State var currentWordKanjiIndex = 0
    @State var completedWordDrawings: [[[CGPoint]]] = []
    @State var wordFeedbackByKanji: [[StrokeFeedback]] = []
    @State var sessionTotalCards = 0
    @State var sessionCompletedCards = 0
    @State var masteredKanjiKeys: Set<String> = []
    @State var masteredWordKeys: Set<String> = []
    @State var masteredKanaKeys: Set<String> = []
    @State var drawnStrokes: [[CGPoint]] = []
    @State var currentStroke: [CGPoint] = []
    @State var feedback: [StrokeFeedback] = []
    @State var guidedStrokeLimit = 1
    @State var showsFeedbackInfo = false
    @State var isAnswerVisible = false
    @State var scrollToTopToken = 0
    @State var selectedWordDeck: WordFrequencyDeck = .top1000
    @State var showsPromptCharacters = false
    @State var showsPromptReading = true
    @State var showsPromptMeaning = false
    @State var frontFieldOrder: [FrontFieldKind] = [.readings, .meanings, .character]
    @State var draggedFrontField: FrontFieldKind?
    @State var frontFieldDragOffset: CGFloat = 0
    @State var frontFieldDragStartIndex: Int?
    @State var isGuidedSingleKanjiPractice = false
    @State var isSettingsPresented = false
    @State var kanjiAgainCounts: [String: Int] = [:]
    @State var kanjiRecoveryGoodCounts: [String: Int] = [:]
    @State var retranslationKanjiMeaningKeys: Set<String> = []
    @State var retranslationKanjiExampleKeys: Set<String> = []
    @State var retranslationWordKeys: Set<String> = []
    @State var kanjiSessionPhase: KanjiLearningSessionPhase = .learning
    @AppStorage("kanjiDailyNewCardLimit") var kanjiDailyNewCardLimit = 10
    @AppStorage("kanjiLearningSuccessTarget") var kanjiLearningSuccessTarget = KanjiReviewStore.defaultLearningSuccessTarget
    @State var meaningLanguage: MeaningLanguage = .russian
    @State var wordMeaningTranslations: [String: String] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if hasStartedTraining {
                    activeTrainingView()
                } else if let previewDeck {
                    deckPreviewView(for: previewDeck)
                } else if let previewKanaDeck {
                    kanaPreviewView(for: previewKanaDeck)
                } else if let previewWordDeck {
                    wordPreviewView(for: previewWordDeck)
                } else {
                    startView()
                }
            }
            .navigationTitle(hasStartedTraining ? "Kanji Trainer" : previewDeck == nil && previewKanaDeck == nil && previewWordDeck == nil ? "Набор карточек" : "Колода")
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
                    .disabled(isLoadingDeck)
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
