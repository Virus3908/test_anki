import Foundation

/// A completed lesson is one review. Easy is never inferred from multiple choice.
nonisolated enum GrammarLessonRating {
    static func rating(correct: Int, total: Int) -> ReviewRating? {
        guard total >= 3, correct >= 0, correct <= total else { return nil }
        if correct == total { return .good }
        return correct * 3 >= total * 2 ? .hard : .again
    }
}
