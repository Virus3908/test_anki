import Foundation

@MainActor
@Observable
final class StudyAppViewModel {
    var practiceMode: PracticeMode = .kanji
    var meaningLanguage: MeaningLanguage = .russian
    var showsPromptCharacters = false
    var showsPromptReading = true
    var showsPromptMeaning = false
    var frontFieldOrder: [FrontFieldKind] = [.readings, .meanings, .character]
    var isSettingsPresented = false
    var isAboutPresented = false
    var deckState = DeckPreviewViewModel()
    var coordinator = StudyCoordinator()
    var trainingSession = TrainingSessionViewModel()
    var translationState = TranslationViewModel()

    var navigationTitle: String {
        if coordinator.hasStartedTraining {
            return "Kanji Trainer"
        }

        if deckState.previewDeck == nil,
           deckState.previewKanaDeck == nil,
           deckState.previewWordDeck == nil {
            return "Набор карточек"
        }

        return "Колода"
    }
}
