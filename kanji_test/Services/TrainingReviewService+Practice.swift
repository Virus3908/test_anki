import Foundation

extension TrainingReviewService {
    static func applyPracticeOnlyReview<Item: StudyItem>(
        item: Item,
        rating: ReviewRating,
        mode: PracticeMode,
        session: inout TrainingSessionState
    ) {
        let answerID = session.currentAnswerID(for: mode)
        let existingAnswer = session.sessionAnswerStates[answerID]
        var answerState = existingAnswer ?? TrainingSessionEngine.makeAnswerState(
            reviewKey: item.reviewKey,
            rating: rating,
            recordBefore: nil,
            againCountBefore: nil,
            recoveryGoodCountBefore: nil,
            wasMastered: false
        )
        answerState.rating = rating
        session.sessionAnswerStates[answerID] = answerState
    }
}
