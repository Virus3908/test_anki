import Foundation

extension TrainingReviewService {
    static func prepareReviewReapply<Item: StudyItem>(
        _ existingAnswer: SessionAnswerState?,
        mode: PracticeMode,
        session: inout TrainingSessionState,
        reviewStore: inout KanjiReviewStore,
        items: inout [Item]
    ) {
        guard let existingAnswer else {
            return
        }

        rollbackFutureSessionAnswers(
            after: session.currentIndex,
            mode: mode,
            session: &session,
            reviewStore: &reviewStore
        )
        restoreSessionAnswer(
            existingAnswer,
            session: &session,
            reviewStore: &reviewStore
        )
        let itemsByKey = Dictionary(items.map { ($0.reviewKey, $0) }, uniquingKeysWith: { first, _ in first })
        items = existingAnswer.queueBefore.compactMap { itemsByKey[$0] }
    }

    static func rollbackFutureSessionAnswers(
        after index: Int,
        mode: PracticeMode,
        session: inout TrainingSessionState,
        reviewStore: inout KanjiReviewStore
    ) {
        let prefix = "\(mode.rawValue):"

        let futureAnswers = session.sessionAnswerStates.compactMap { answerID, answer -> (String, Int, SessionAnswerState)? in
            guard answerID.hasPrefix(prefix) else {
                return nil
            }

            let indexText = answerID.dropFirst(prefix.count)
            guard let answerIndex = Int(indexText), answerIndex > index else {
                return nil
            }

            return (answerID, answerIndex, answer)
        }
        .sorted { left, right in
            left.1 > right.1
        }

        for (answerID, _, answer) in futureAnswers {
            restoreSessionAnswer(answer, session: &session, reviewStore: &reviewStore)
            session.sessionAnswerStates[answerID] = nil
        }
    }

    static func restoreSessionAnswer(
        _ answer: SessionAnswerState,
        session: inout TrainingSessionState,
        reviewStore: inout KanjiReviewStore
    ) {
        reviewStore.restore(answer.recordBefore, for: answer.reviewKey)
        restoreCounter(answer.againCountBefore, for: answer.reviewKey, in: &session.kanjiAgainCounts)
        restoreCounter(answer.recoveryGoodCountBefore, for: answer.reviewKey, in: &session.kanjiRecoveryGoodCounts)

        if answer.wasMastered {
            session.masteredKeys.insert(answer.reviewKey)
        } else {
            session.masteredKeys.remove(answer.reviewKey)
        }
        session.sessionCompletedCards = session.masteredKeys.count
    }

    static func restoreCounter(_ value: Int?, for key: String, in dictionary: inout [String: Int]) {
        if let value {
            dictionary[key] = value
        } else {
            dictionary[key] = nil
        }
    }

}
