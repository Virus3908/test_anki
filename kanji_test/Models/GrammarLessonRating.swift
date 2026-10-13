import Foundation

/// One completed attempt, including assistance. Easy always requires explicit self-assessment.
nonisolated enum GrammarLessonRating {
    /// Difficulty weights 1/2/3. Below 2/3 weighted accuracy is Again;
    /// any error or assistance is Hard, otherwise Good. Never automatic Easy.
    static func rating(results: [GrammarExerciseResult], exercises: [GrammarExercise]) -> ReviewRating? {
        guard exercises.allSatisfy({ $0.eligibleForPractice }), results.count >= 3, results.count == exercises.count,
              !results.contains(where: { $0.assessment == .differsFromSample }),
              Set(results.map(\.exerciseID)).count == results.count,
              Set(results.map(\.exerciseID)) == Set(exercises.map(\.id)) else { return nil }
        var total = 0, correct = 0
        for result in results {
            guard let exercise = exercises.first(where: { $0.id == result.exerciseID }),
                  (1...3).contains(exercise.difficulty) else { return nil }
            total += exercise.difficulty
            if result.isCorrect { correct += exercise.difficulty }
        }
        if correct * 3 < total * 2 { return .again }
        return results.allSatisfy { $0.isCorrect && !$0.usedHint } ? .good : .hard
    }
    static func rating(correct: Int, total: Int, hints: Int = 0) -> ReviewRating? {
        guard total >= 3, correct >= 0, correct <= total, hints >= 0, hints <= total else { return nil }
        if correct * 3 < total * 2 { return .again }
        return correct == total && hints == 0 ? .good : .hard
    }
}
