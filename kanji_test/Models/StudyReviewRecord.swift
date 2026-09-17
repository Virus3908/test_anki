import Foundation

nonisolated enum StudyReviewState: String, Codable, Sendable {
    case learning, review, relearning
}

nonisolated struct StudyReviewRecord: Codable, Sendable {
    var attempts: Int
    var intervalDays: Double
    var dueDate: Date
    var lastRating: ReviewRating
    var lastReviewedAt: Date
    var state: StudyReviewState
    var learningStep: Int
    var lapses: Int
    var stability: Double
    var difficulty: Double
    var schedulerVersion: String

    var logInterval: Double {
        intervalDays > 0 ? intervalDays : -max(0, dueDate.timeIntervalSince(lastReviewedAt))
    }
}
