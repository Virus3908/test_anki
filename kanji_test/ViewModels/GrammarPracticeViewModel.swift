import Foundation
import Observation

/// Transient lesson state. Scheduling and persistence belong to the shared session.
@MainActor
@Observable
final class GrammarPracticeViewModel {
    nonisolated struct RecallPrompt: Identifiable, Sendable {
        let id: String
        let question: String
        let cue: String
        let sourceAnswer: String
    }
    let rule: GrammarRule
    private(set) var exercises: [GrammarExercise]
    let isFreePractice: Bool
    let isReview: Bool
    let attempt: Int
    let recallPrompts: [RecallPrompt]
    private(set) var isClosed = false
    private(set) var position = 0
    private(set) var selectedOptionID: String?
    private(set) var selectedElements: [String] = []
    var textAnswer = ""
    private(set) var isAnswerVisible = false
    private(set) var usedHint = false
    private(set) var results: [GrammarExerciseResult] = []
    private(set) var isSaving = false
    private(set) var isSaved = false
    var isLessonRead: Bool
    private let seed: String
    private var reserve: [GrammarExercise]
    private var remediationCount = 0
    private let previousRating: ReviewRating?
    private let initialExercises: [GrammarExercise]
    private let initialReserve: [GrammarExercise]
    static let maximumCount = GrammarExerciseEngine.maximumCount

    init(rule: GrammarRule, seed: String, freePractice: Bool = false, isReview: Bool = false, attempt: Int = 0,
         previousRating: ReviewRating? = nil) {
        self.rule = rule; self.seed = seed; self.attempt = attempt
        isFreePractice = freePractice; self.isReview = isReview; isLessonRead = isReview
        self.previousRating = previousRating
        let plan = GrammarExerciseEngine.plan(rule: rule, seed: seed, isReview: isReview, attempt: attempt, previousRating: previousRating)
        exercises = plan.exercises; reserve = plan.reserve
        initialExercises = plan.exercises; initialReserve = plan.reserve
        let example = GrammarExerciseSelection.ordered(rule.examples + rule.studyExamples, seed: seed)
            .first ?? GrammarExample(ja: "", en: "", furigana: nil, ru: nil)
        recallPrompts = [
            RecallPrompt(id: "\(rule.id):meaning", question: "Объясни смысл в контексте.", cue: rule.pattern, sourceAnswer: rule.displayedMeaning),
            RecallPrompt(id: "\(rule.id):formation", question: "Вспомни образование.", cue: rule.pattern, sourceAnswer: rule.displayedFormation),
            RecallPrompt(id: "\(rule.id):example", question: "Объясни смысл предложения.", cue: example.ja, sourceAnswer: example.ru ?? example.en)
        ]
    }

    var isSelfAssessment: Bool { isFreePractice }
    var contentError: String? {
        !isFreePractice && exercises.isEmpty ? "Практика для этого правила ещё готовится. Все объяснения и примеры доступны." : nil
    }
    var correctCount: Int { results.filter(\.isCorrect).count }
    var proposedRating: ReviewRating? {
        isComplete && !isSelfAssessment && !isClosed && !isSaved
            ? GrammarLessonRating.rating(results: results, exercises: exercises) : nil
    }
    var weakAspects: [String] {
        var seen = Set<String>()
        return results.filter { $0.hasVerifiedError || $0.usedHint }.compactMap { result in
            guard let exercise = exercises.first(where: { $0.id == result.exerciseID }),
                  let aspect = exercise.aspect, seen.insert(aspect).inserted else { return nil }
            return aspect
        }
    }
    func close() { isClosed = true }
    func restartAttempt() {
        exercises = initialExercises; reserve = initialReserve; remediationCount = 0
        position = 0; results = []; selectedOptionID = nil; selectedElements = []; textAnswer = ""
        isAnswerVisible = false; usedHint = false; isSaved = false; isSaving = false; isClosed = false
        isLessonRead = isReview
    }
    func beginSaving() -> ReviewRating? {
        guard !isSaving, let rating = proposedRating else { return nil }
        isSaving = true
        return rating
    }
    func finishSaving(success: Bool) { isSaving = false; isSaved = success }
    var count: Int { isSelfAssessment ? recallPrompts.count : exercises.count }
    var isComplete: Bool { contentError == nil && count > 0 && position >= count }
    var currentExercise: GrammarExercise? { exercises[safe: position] }
    var currentRecall: RecallPrompt? { recallPrompts[safe: position] }
    var options: [GrammarExercise.Option] {
        guard let exercise = currentExercise else { return [] }
        return GrammarExerciseSelection.ordered(exercise.options, seed: seed + exercise.id)
    }

    func useHint() {
        guard !isClosed, !isComplete, !isAnswerVisible, contentError == nil else { return }
        usedHint = true
    }
    func choose(_ optionID: String) {
        guard !isClosed, contentError == nil, !isAnswerVisible, let exercise = currentExercise,
              exercise.kind != .assembleSentence, exercise.kind != .restoreSentence, exercise.options.contains(where: { $0.id == optionID }) else { return }
        selectedOptionID = optionID
        record(correct: exercise.accepts(optionID), answer: optionID)
    }
    func toggleElement(_ id: String) {
        guard !isClosed, !isAnswerVisible, currentExercise?.kind == .assembleSentence,
              options.contains(where: { $0.id == id }) else { return }
        if let index = selectedElements.firstIndex(of: id) { selectedElements.remove(at: index) }
        else { selectedElements.append(id) }
    }
    func checkAssembly() {
        guard !isClosed, !isAnswerVisible, contentError == nil, let exercise = currentExercise,
              exercise.kind == .assembleSentence, !selectedElements.isEmpty else { return }
        let correct = exercise.accepts(order: selectedElements)
        let permittedElements = Set((exercise.acceptedOrders ?? []).flatMap { $0 })
        let diagnosed = selectedElements.contains { id in
            !permittedElements.contains(id) && exercise.options.first { $0.id == id }?.feedbackRU?.isEmpty == false
        }
        let assessment: GrammarAnswerValidator.Assessment = correct ? .correct : diagnosed ? .incorrectForm : .differsFromSample
        record(correct: correct, answer: selectedElements.joined(separator: "|"), assessment: assessment)
    }
    func checkForm() {
        guard !isClosed, !isAnswerVisible, contentError == nil, let exercise = currentExercise,
              (exercise.kind == .formProduction || exercise.kind == .restoreSentence), !textAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let assessment = GrammarAnswerValidator.assess(textAnswer, for: exercise)
        record(correct: assessment == .correct, answer: textAnswer, assessment: assessment)
    }
    private func record(correct: Bool, answer: String, assessment: GrammarAnswerValidator.Assessment? = nil) {
        guard let exercise = currentExercise else { return }
        isAnswerVisible = true
        results.append(GrammarExerciseResult(exerciseID: exercise.id, optionID: answer, isCorrect: correct, usedHint: usedHint, assessment: assessment))
        if ((!correct && assessment != .differsFromSample) || usedHint), remediationCount < 2, exercises.count < Self.maximumCount,
           let index = reserve.firstIndex(where: { $0.aspect == exercise.aspect && $0.aspect != nil }) {
            // Another context for the same skill; no repeated question, no unbounded extension.
            exercises.insert(reserve.remove(at: index), at: position + 1)
            remediationCount += 1
        }
        if isReview, previousRating != .again, results.count >= 3,
           results.allSatisfy({ $0.isCorrect && !$0.usedHint }) {
            let answered = Set(results.compactMap { result in exercises.first { $0.id == result.exerciseID }?.kind })
            let formation = !answered.isDisjoint(with: [.formProduction, .fillBlank, .transformSentence, .correctError])
            let context = !answered.isDisjoint(with: [.chooseContext, .understandSentence, .distinguishMeaning])
            let application = !answered.isDisjoint(with: [.transformSentence, .assembleSentence])
            if formation && context && application { exercises = Array(exercises.prefix(position + 1)) }
        }
    }
    func reveal() { guard !isClosed, isSelfAssessment, !isComplete else { return }; isAnswerVisible = true }
    func next() {
        guard !isClosed, contentError == nil, isAnswerVisible, !isComplete else { return }
        position += 1; selectedOptionID = nil; selectedElements = []; textAnswer = ""; isAnswerVisible = false; usedHint = false
    }
}
