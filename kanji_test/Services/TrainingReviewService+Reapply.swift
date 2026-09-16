import Foundation

extension TrainingReviewService {
    static func prepareReviewReapply<Item: StudyItem>(
        _ existingAnswer: SessionAnswerState?,
        key: String,
        mode: PracticeMode,
        session: TrainingSessionViewModel,
        reviewStore: inout KanjiReviewStore,
        masteredKeys: inout Set<String>,
        items: inout [Item]
    ) {
        guard let existingAnswer else {
            return
        }

        restoreSessionAnswer(
            existingAnswer,
            session: session,
            reviewStore: &reviewStore,
            masteredKeys: &masteredKeys
        )
        removeFutureRepeats(after: session.currentIndex, key: key, from: &items)
        rollbackFutureSessionAnswers(
            after: session.currentIndex,
            mode: mode,
            session: session,
            reviewStore: &reviewStore,
            masteredKeys: &masteredKeys,
            items: &items
        )
    }

    static func rollbackFutureSessionAnswers<Item: StudyItem>(
        after index: Int,
        mode: PracticeMode,
        session: TrainingSessionViewModel,
        reviewStore: inout KanjiReviewStore,
        masteredKeys: inout Set<String>,
        items: inout [Item]
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
            restoreSessionAnswer(answer, session: session, reviewStore: &reviewStore, masteredKeys: &masteredKeys)
            removeFutureRepeats(after: index, key: answer.reviewKey, from: &items)
            session.sessionAnswerStates[answerID] = nil
        }
    }

    static func restoreSessionAnswer(
        _ answer: SessionAnswerState,
        session: TrainingSessionViewModel,
        reviewStore: inout KanjiReviewStore,
        masteredKeys: inout Set<String>
    ) {
        reviewStore.restore(answer.recordBefore, for: answer.reviewKey)
        ReviewRepository.save(reviewStore)
        restoreCounter(answer.againCountBefore, for: answer.reviewKey, in: &session.kanjiAgainCounts)
        restoreCounter(answer.recoveryGoodCountBefore, for: answer.reviewKey, in: &session.kanjiRecoveryGoodCounts)

        if answer.wasMastered {
            masteredKeys.insert(answer.reviewKey)
        } else {
            masteredKeys.remove(answer.reviewKey)
        }
        session.sessionCompletedCards = masteredKeys.count
    }

    static func restoreCounter(_ value: Int?, for key: String, in dictionary: inout [String: Int]) {
        if let value {
            dictionary[key] = value
        } else {
            dictionary[key] = nil
        }
    }

    static func removeFutureRepeats<Item: StudyItem>(
        after index: Int,
        key: String,
        from items: inout [Item]
    ) {
        TrainingSessionEngine.removeFutureRepeats(
            after: index,
            key: key,
            items: &items
        )
    }
}
