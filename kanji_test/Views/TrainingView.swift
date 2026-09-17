import SwiftUI

struct TrainingView: View, CardContentRendering {
    let trainingSession: TrainingSessionViewModel
    let settings: StudyPreferences
    let translationState: TranslationViewModel
    let coordinator: StudyCoordinator
    let onPractice: (PracticeSelection) -> Void
    var reviewStore: KanjiReviewStore { trainingSession.reviewStore }
    var drawingSession: DrawingSessionViewModel { trainingSession.drawingSession }
    var practiceMode: PracticeMode { trainingSession.mode ?? .kanji }
    var cards: [KanjiCard] { trainingSession.cards }
    var wordCards: [WordStudyCard] { trainingSession.wordCards }
    var kanaCards: [KanaStudyCard] { trainingSession.kanaCards }
    var body: some View { activeTrainingView().disabled(trainingSession.isPreparingCard) }
    var trainingTitle: String {
        switch practiceMode {
        case .kanji: return selectedDeck.title
        case .words: return "Слова: \(selectedWordDeck.title)"
        case .kana: return selectedKanaDeck.title
        }
    }
    func finishTraining() { trainingSession.finish() }
    func moveToPreviousCard() { Task { await trainingSession.moveToPreviousCard() } }
    func moveToNextCard() { Task { await trainingSession.moveToNextCard() } }
    func applyWordReview(_ rating: ReviewRating) {
        let key = wordCards[safe: trainingSession.currentIndex]?.reviewKey
        Task { await trainingSession.submitReview(rating, expectedKey: key) }
    }
    func applyKanaReview(_ rating: ReviewRating) {
        let key = kanaCards[safe: trainingSession.currentIndex]?.reviewKey
        Task { await trainingSession.submitReview(rating, expectedKey: key) }
    }
    func applyReview(_ rating: ReviewRating, to card: KanjiCard) {
        Task { await trainingSession.submitReview(rating, expectedKey: card.reviewKey) }
    }
    func updateFeedback(for card: KanjiCard, reveal: Bool) {
        if trainingSession.evaluateFeedback(for: card, reveal: reveal) { revealDrawingAnswer() }
    }
}
