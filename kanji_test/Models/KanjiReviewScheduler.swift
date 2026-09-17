import Foundation

nonisolated enum KanjiReviewScheduler {
    static func record(
        after rating: ReviewRating,
        existingRecord: KanjiReviewRecord?,
        learningSuccessTarget: Int,
        resetIntervalOnGood: Bool,
        now: Date
    ) -> KanjiReviewRecord {
        let successTarget = max(1, learningSuccessTarget)
        var record = existingRecord ?? KanjiReviewRecord(
            attempts: 0,
            successes: 0,
            streak: 0,
            intervalDays: 0,
            dueDate: now,
            lastRating: rating,
            lastReviewedAt: now
        )

        record.attempts += 1
        record.lastRating = rating
        record.lastReviewedAt = now

        switch rating {
        case .again:
            applyAgain(to: &record, now: now)
        case .hard:
            applyHard(to: &record, now: now)
        case .good:
            applyGood(
                to: &record,
                successTarget: successTarget,
                resetIntervalOnGood: resetIntervalOnGood,
                now: now
            )
        }

        return record
    }

    private static func applyAgain(to record: inout KanjiReviewRecord, now: Date) {
        record.streak = 0
        if record.state == .review {
            record.state = .relearning
            record.lapses += 1
            record.learningStep = 0
            record.easeFactor = max(1.3, record.easeFactor - 0.2)
            record.intervalDays = max(1, min(record.intervalDays, 1))
            record.dueDate = now
        } else {
            record.state = .learning
            record.learningStep = 0
            record.intervalDays = 0
            record.dueDate = now
        }
    }

    private static func applyHard(to record: inout KanjiReviewRecord, now: Date) {
        record.streak = 0
        record.easeFactor = max(1.3, record.easeFactor - 0.15)
        if record.state == .review {
            let nextInterval = max(1, min(record.intervalDays * 1.2, 180))
            record.intervalDays = nextInterval
            record.dueDate = date(now, addingDays: Int(ceil(nextInterval)))
        } else {
            record.learningStep = max(0, record.learningStep - 1)
            record.intervalDays = 0
            record.dueDate = now
        }
    }

    private static func applyGood(
        to record: inout KanjiReviewRecord,
        successTarget: Int,
        resetIntervalOnGood: Bool,
        now: Date
    ) {
        record.successes += 1
        record.streak += 1

        switch record.state {
        case .learning:
            record.learningStep += 1
            if record.learningStep >= successTarget {
                record.state = .review
                record.intervalDays = 1
                record.dueDate = nextDay(after: now)
            } else {
                record.intervalDays = 0
                record.dueDate = now
            }
        case .relearning:
            record.learningStep += 1
            let relearningTarget = 1
            if record.learningStep >= relearningTarget {
                record.state = .review
                record.intervalDays = 1
                record.dueDate = nextDay(after: now)
            } else {
                record.intervalDays = 0
                record.dueDate = now
            }
        case .review:
            if resetIntervalOnGood || record.intervalDays == 0 {
                record.intervalDays = 1
            } else {
                record.intervalDays = min(max(1, record.intervalDays * record.easeFactor), 180)
            }
            record.dueDate = date(now, addingDays: Int(ceil(record.intervalDays)))
        }
    }

    private static func nextDay(after date: Date) -> Date {
        self.date(date, addingDays: 1)
    }

    private static func date(_ date: Date, addingDays days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date.addingTimeInterval(Double(days) * 24 * 60 * 60)
    }
}
