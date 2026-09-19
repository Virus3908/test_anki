import Foundation

/// Persisted app reviews and bootstrapped Anki revlog rows share this audit format.
nonisolated struct StudyReviewLog: Codable, Sendable, Identifiable {
    let id: UUID
    let cardID: String
    let deckID: String
    let grade: Int
    let reviewedAt: Date
    let elapsedDays: Int
    let previousInterval: Double
    let scheduledInterval: Double
    let stateBefore: StudyReviewState?
    let stability: Double?
    let difficulty: Double?
    let schedulerVersion: String
    let countsTowardReviewLimit: Bool
}
