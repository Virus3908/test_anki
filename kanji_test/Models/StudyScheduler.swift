import Foundation
import FSRS

/// FSRS-6 memory model with Anki-style learning steps and local calendar day boundaries.
/// Only this adapter knows the external library; storage/UI keep app-owned models.
nonisolated enum StudyScheduler {
    static let version = "fsrs-6"

    enum Error: LocalizedError {
        case invalidRating

        var errorDescription: String? {
            switch self {
            case .invalidRating: return "Не удалось преобразовать оценку в формат планировщика."
            }
        }
    }

    static func record(after rating: ReviewRating, cardID: String, existingRecord: StudyReviewRecord?,
                       options: DeckOptions, now: Date) throws -> StudyReviewRecord {
        let options = options.validated
        let calendar = Calendar.current
        let previous = existingRecord
        let elapsed = previous.map {
            max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.lastReviewedAt),
                                           to: calendar.startOfDay(for: now)).day ?? 0)
        } ?? 0
        let parameters = FSRSParameters(requestRetention: options.desiredRetention,
            maximumInterval: Double(options.maximumInterval), w: FSRSDefaults.defaultWv6,
            enableFuzz: true, enableShortTerm: true, learningSteps: [], relearningSteps: [])
        let scheduler = FSRS(parameters: parameters)
        // Upstream seeds fuzz with reviewTime. Keep that seed stable for this card/day so
        // button previews and the saved answer agree, without synchronizing all cards.
        let hash = cardID.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        let day = floor(calendar.startOfDay(for: now).timeIntervalSince1970 / 86400) * 86400
        let schedulerNow = Date(timeIntervalSince1970: day + Double(hash % 86400))
        var card = Card(due: now)
        if let previous {
            card.state = previous.state == .review ? .review : previous.state == .relearning ? .relearning : .learning
            card.stability = previous.stability
            card.difficulty = previous.difficulty
            card.scheduledDays = previous.intervalDays
            card.reps = previous.attempts
            card.lapses = previous.lapses
            // swift-fsrs counts UTC day boundaries; align its elapsed-day input with our calendar.
            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(secondsFromGMT: 0)!
            card.lastReview = utc.startOfDay(for: schedulerNow).addingTimeInterval(-Double(elapsed) * 86400)
        }
        guard let grade = Rating(rawValue: rating.ankiGrade) else { throw Error.invalidRating }
        let result = try scheduler.next(card: card, now: schedulerNow, grade: grade).card
        var record = previous ?? StudyReviewRecord(attempts: 0, intervalDays: 0, dueDate: now,
            lastRating: rating, lastReviewedAt: now, state: .learning, learningStep: 0, lapses: 0,
            stability: result.stability, difficulty: result.difficulty, schedulerVersion: version)
        record.attempts += 1
        record.lastRating = rating
        record.lastReviewedAt = now
        record.stability = result.stability
        record.difficulty = result.difficulty
        record.schedulerVersion = version
        if previous?.state == .review && rating == .again { record.lapses += 1 }
        record.state = .review
        record.learningStep = 0
        let days = min(options.maximumInterval, max(1, Int(result.scheduledDays)))
        record.intervalDays = Double(days)
        record.dueDate = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(Double(days) * 86400)

        let isLapse = previous?.state == .review && rating == .again
        let isRelearning = isLapse || previous?.state == .relearning
        let steps = isRelearning ? options.relearningSteps : options.learningSteps
        if rating != .easy, (previous?.state != .review || isLapse), !steps.isEmpty {
            let currentStep = min(max(0, previous?.learningStep ?? 0), steps.count - 1)
            let step: Int
            let minutes: Double?
            switch rating {
            case .again: step = 0; minutes = Double(steps[0])
            case .hard:
                step = currentStep
                minutes = currentStep > 0 ? Double(steps[currentStep]) :
                    (steps.count > 1 ? Double(steps[0] + steps[1]) / 2 : Double(steps[0]) * 1.5)
            case .good:
                step = currentStep + 1
                minutes = step < steps.count ? Double(steps[step]) : nil
            case .easy: step = 0; minutes = nil
            }
            if let minutes {
                record.state = isRelearning ? .relearning : .learning
                record.learningStep = step
                let due = now.addingTimeInterval(minutes * 60)
                let crossesDay = !calendar.isDate(now, inSameDayAs: due)
                record.dueDate = crossesDay ? calendar.startOfDay(for: due) : due
                record.intervalDays = crossesDay ? Double(calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: due)).day ?? 1) : 0
            }
        }
        return record
    }
}
