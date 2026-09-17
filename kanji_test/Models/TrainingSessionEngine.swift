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
        let items = sourceIDs.filter { seen.insert($0).inserted }.map { ReviewItem(id: $0, mode: mode) }
        let keys = Set(items.map(\.reviewKey))
        let newLimit = progress.remainingNewCards(limit: options.dailyNewCardLimit, keys: keys, now: now)
        let reviewLimit = progress.remainingReviews(limit: options.dailyReviewLimit, deckID: deckID, now: now)
        var learning: [ReviewItem] = []
        var reviews: [ReviewItem] = []
        var started: [ReviewItem] = []
        var fresh: [ReviewItem] = []
        var nextLearning: Date?
        for item in items {
            if let record = progress.record(for: item.reviewKey) {
                if progress.isDue(record, now: now) {
                    if progress.consumesReviewLimit(record) { reviews.append(item) }
                    else { learning.append(item) }
                } else if record.state != .review,
                          Calendar.current.isDate(record.dueDate, inSameDayAs: date) {
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
        let selectedReviews = Array(reviews.prefix(reviewLimit))
        // As in Anki's default: reaching the review cap pauses introductions,
        // while cards already being learned today can complete their steps.
        let selectedNew = reviewLimit > 0 ? Array(fresh.prefix(newLimit)) : []
        return StudyQueuePlan(readyIDs: (learning + selectedReviews + started + selectedNew).map(\.id),
                              nextLearningDate: nextLearning, hiddenReviews: max(0, reviews.count - selectedReviews.count))
    }
}
