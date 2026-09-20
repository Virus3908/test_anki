import SwiftUI

struct TrainingView: View, CardContentRendering {
    @State var isCardFieldSettingsPresented = false
    var deckID: String? { trainingSession.deck?.id }
    let trainingSession: TrainingSessionViewModel
    let settings: StudyPreferences
    let translationState: TranslationViewModel
    let coordinator: StudyCoordinator
    let onPractice: (PracticeSelection) -> Void
    var reviewStore: StudyProgressStore { trainingSession.reviewStore }
    var drawingSession: DrawingSessionViewModel { trainingSession.drawingSession }
    var practiceMode: PracticeMode { trainingSession.mode ?? .kanji }
    var cards: [KanjiCard] { trainingSession.cards }
    var wordCards: [WordStudyCard] { trainingSession.wordCards }
    var kanaCards: [KanaStudyCard] { trainingSession.kanaCards }
    var body: some View {
        activeTrainingView()
            .disabled(trainingSession.isPreparingCard)
            .onChange(of: trainingSession.options) { Task { await trainingSession.refreshForNewDay() } }
            .task(id: trainingSession.state.nextLearningDate) {
                guard let date = trainingSession.state.nextLearningDate else { return }
                let delay = max(0, date.timeIntervalSince(trainingSession.reviewStore.studyDate()))
                do { try await Task.sleep(for: .seconds(delay + 0.1)) }
                catch { return }
                await trainingSession.refreshForNewDay()
            }
    }
    func sessionWaitingView() -> some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle").font(.largeTitle).foregroundStyle(AppPalette.success)
            Text("На сейчас всё готово").font(.title2)
            if let next = trainingSession.state.nextLearningDate {
                Text("Следующий шаг обучения: \(next.formatted(date: .omitted, time: .shortened))")
            }
            if trainingSession.state.hiddenReviews > 0 {
                Text("Дневной лимит достигнут. Осталось повторений: \(trainingSession.state.hiddenReviews). Лимит можно изменить в настройках этой колоды.")
                    .font(.callout).multilineTextAlignment(.center)
            }
            if trainingSession.canGoBack {
                Button("Отменить последний ответ", systemImage: "arrow.uturn.backward") { moveToPreviousCard() }
            }
            Button("Вернуться к колоде", action: finishTraining).buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
    var trainingTitle: String {
        if let deck = trainingSession.deck { return deck.title }
        switch practiceMode {
        case .kanji: return selectedDeck.title
        case .words: return "Слова: \(selectedWordDeck.title)"
        case .kana: return selectedKanaDeck.title
        case .anki: return "Анки"
        }
    }
    func finishTraining() { trainingSession.finish() }
    func moveToPreviousCard() { Task { await trainingSession.moveToPreviousCard() } }
    func moveToNextCard() { Task { await trainingSession.moveToNextCard() } }
    func excludeCurrentCard() { Task { await trainingSession.excludeCurrentCard() } }
    func applyWordReview(_ rating: ReviewRating) {
        let key = wordCards[safe: trainingSession.currentIndex]?.reviewKey
        Task { await trainingSession.submitReview(rating, expectedKey: key) }
    }
    func applyKanaReview(_ rating: ReviewRating) {
        let key = kanaCards[safe: trainingSession.currentIndex]?.reviewKey
        Task { await trainingSession.submitReview(rating, expectedKey: key) }
    }
    func applyAnkiReview(_ rating: ReviewRating) {
        guard let key = trainingSession.currentAnkiCard?.reviewKey else { return }
        Task { await trainingSession.submitReview(rating, expectedKey: key) }
    }
    func applyReview(_ rating: ReviewRating, to card: KanjiCard) {
        Task { await trainingSession.submitReview(rating, expectedKey: card.reviewKey) }
    }
    func updateFeedback(for card: KanjiCard, reveal: Bool) {
        if trainingSession.evaluateFeedback(for: card, reveal: reveal) { revealDrawingAnswer() }
    }
}
