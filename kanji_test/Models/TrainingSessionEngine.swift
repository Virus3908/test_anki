import Foundation

struct SessionAnswerState {
    let reviewKey: String
    var rating: ReviewRating
}

struct ReviewUndo {
    let id: String
    let reviewKey: String
    let recordBefore: StudyReviewRecord?
    let logID: UUID
}

nonisolated struct StudyQueuePlan {
    let readyIDs: [String]
    /// All cards still assigned to this study day, including cards waiting for
    /// their next intraday learning step.
    let todayIDs: [String]
    let newCount: Int
    let learningCount: Int
    let reviewCount: Int
    let nextLearningDate: Date?
    let hiddenReviews: Int
}

/// Rebuild from persisted due dates after every answer; no fixed-position repeats.
nonisolated enum TrainingSessionEngine {
    static func plan(sourceIDs: [String], mode: PracticeMode, deckID: String,
                     progress: StudyProgressStore, options: DeckOptions, now: Date = Date()) -> StudyQueuePlan {
        let date = progress.studyDate(now: now)
        let options = options.validated
        var seen: Set<String> = []
        let items = sourceIDs
            .filter { seen.insert($0).inserted }
            .map { ReviewItem(id: $0, mode: mode) }
            .filter { !progress.isExcluded($0.reviewKey) }
        let keys = Set(items.map(\.reviewKey))
        let newLimit = progress.remainingNewCards(limit: options.dailyNewCardLimit, keys: keys, now: now)
        let dailyLimit = progress.remainingDailyCards(
            limit: options.dailyReviewLimit,
            deckID: deckID,
            keys: keys,
            now: now
        )
        var learning: [ReviewItem] = []
        var reviews: [ReviewItem] = []
        var started: [ReviewItem] = []
        var fresh: [ReviewItem] = []
        var waitingLearning: [ReviewItem] = []
        var nextLearning: Date?
        for item in items {
            if let record = progress.record(for: item.reviewKey) {
                if progress.isDue(record, now: now) {
                    if progress.consumesReviewLimit(record) { reviews.append(item) }
                    else { learning.append(item) }
                } else if record.state != .review,
                          Calendar.current.isDate(record.dueDate, inSameDayAs: date) {
                    // A learning/relearning step later today remains part of
                    // today's workload, even while it cannot be shown yet.
                    waitingLearning.append(item)
                    nextLearning = min(nextLearning ?? record.dueDate, record.dueDate)
                }
            } else if progress.firstShownAt[item.reviewKey] != nil { started.append(item) }
            else { fresh.append(item) }
        }
        let byDue: (ReviewItem, ReviewItem) -> Bool = {
            let left = progress.records[$0.reviewKey]?.dueDate ?? .distantPast
            let right = progress.records[$1.reviewKey]?.dueDate ?? .distantPast
            return left == right ? $0.reviewKey < $1.reviewKey : left < right
        }
        learning.sort(by: byDue)
        reviews.sort(by: byDue)
        waitingLearning.sort(by: byDue)
        // Reviews have priority within the shared daily budget. New cards use
        // only the slots left after all selected reviews, and also keep their
        // own introduction limit.
        let selectedReviews = Array(reviews.prefix(dailyLimit))
        let remainingSlots = dailyLimit == Int.max
            ? newLimit
            : min(newLimit, max(0, dailyLimit - selectedReviews.count))
        let selectedNew = Array(fresh.prefix(remainingSlots))
        let ready = learning + selectedReviews + started + selectedNew
        // Do not leave a study session empty just because the next learning
        // step is a few minutes away. New and due cards still take priority;
        // this fallback is used only after they are exhausted.
        let display = ready.isEmpty ? Array(waitingLearning.prefix(1)) : ready
        let today = learning + waitingLearning + reviews + started + selectedNew
        return StudyQueuePlan(
            readyIDs: display.map(\.id),
            todayIDs: today.map(\.id),
            newCount: selectedNew.count,
            learningCount: learning.count + waitingLearning.count + started.count,
            reviewCount: selectedReviews.count,
            nextLearningDate: nextLearning,
            hiddenReviews: max(0, reviews.count - selectedReviews.count)
        )
    }
}
