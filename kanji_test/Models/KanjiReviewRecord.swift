import Foundation

nonisolated enum KanjiReviewState: String, Codable, Sendable {
    case learning
    case review
    case relearning
}

nonisolated struct KanjiReviewRecord: Codable, Sendable {
    var attempts: Int
    var successes: Int
    var streak: Int
    var intervalDays: Double
    var dueDate: Date
    var lastRating: ReviewRating
    var lastReviewedAt: Date
    var state: KanjiReviewState
    var learningStep: Int
    var easeFactor: Double
    var lapses: Int

    init(
        attempts: Int,
        successes: Int,
        streak: Int,
        intervalDays: Double,
        dueDate: Date,
        lastRating: ReviewRating,
        lastReviewedAt: Date,
        state: KanjiReviewState = .learning,
        learningStep: Int = 0,
        easeFactor: Double = 2.5,
        lapses: Int = 0
    ) {
        self.attempts = attempts
        self.successes = successes
        self.streak = streak
        self.intervalDays = intervalDays
        self.dueDate = dueDate
        self.lastRating = lastRating
        self.lastReviewedAt = lastReviewedAt
        self.state = state
        self.learningStep = learningStep
        self.easeFactor = easeFactor
        self.lapses = lapses
    }

    enum CodingKeys: String, CodingKey {
        case attempts
        case successes
        case streak
        case intervalDays
        case dueDate
        case lastRating
        case lastReviewedAt
        case state
        case learningStep
        case easeFactor
        case lapses
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attempts = try container.decodeIfPresent(Int.self, forKey: .attempts) ?? 0
        successes = try container.decodeIfPresent(Int.self, forKey: .successes) ?? 0
        streak = try container.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        intervalDays = try container.decodeIfPresent(Double.self, forKey: .intervalDays) ?? 0
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate) ?? Date()
        lastRating = try container.decodeIfPresent(ReviewRating.self, forKey: .lastRating) ?? .again
        lastReviewedAt = try container.decodeIfPresent(Date.self, forKey: .lastReviewedAt) ?? Date()
        learningStep = try container.decodeIfPresent(Int.self, forKey: .learningStep) ?? min(successes, KanjiReviewStore.defaultLearningSuccessTarget)
        easeFactor = max(1.3, try container.decodeIfPresent(Double.self, forKey: .easeFactor) ?? 2.5)
        lapses = try container.decodeIfPresent(Int.self, forKey: .lapses) ?? 0

        if let decodedState = try container.decodeIfPresent(KanjiReviewState.self, forKey: .state) {
            state = decodedState
        } else {
            state = successes >= KanjiReviewStore.defaultLearningSuccessTarget ? .review : .learning
        }
    }
}
