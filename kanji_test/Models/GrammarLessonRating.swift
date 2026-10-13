import Foundation

/// One completed attempt, including assistance. Easy always requires explicit self-assessment.
nonisolated enum GrammarLessonRating {
    static func rating(correct: Int, total: Int, hints: Int = 0) -> ReviewRating? {
        guard total >= 3, correct >= 0, correct <= total, hints >= 0, hints <= total else { return nil }
        if correct * 3 < total * 2 { return .again }
        return correct == total && hints == 0 ? .good : .hard
    }
}
