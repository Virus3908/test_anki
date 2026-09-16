import SwiftUI

extension ContentView {
    func applyWordReview(_ rating: ReviewRating) {
        let shouldAdvance = applyCurrentItemReview(
            rating: rating,
            masteredKeys: &trainingSession.masteredWordKeys,
            items: &wordCards
        )

        if !shouldAdvance {
            return
        }

        advanceToNextWordOrFinish()
    }

    func advanceToNextWordOrFinish() {
        advanceToNextOrFinish(
            hasNextCard: trainingSession.currentIndex < wordCards.count - 1,
            startNextPack: startNextWordPack
        ) {
            trainingSession.moveToNextCard(resetWordDrawing: true)
        }
    }

    func applyKanaReview(_ rating: ReviewRating) {
        let shouldAdvance = applyCurrentItemReview(
            rating: rating,
            masteredKeys: &trainingSession.masteredKanaKeys,
            items: &kanaCards
        )

        if !shouldAdvance {
            return
        }

        advanceToNextKanaOrFinish()
    }

    func advanceToNextKanaOrFinish() {
        advanceToNextOrFinish(
            hasNextCard: trainingSession.currentIndex < kanaCards.count - 1,
            startNextPack: startNextKanaPack
        ) {
            trainingSession.moveToNextCard()
        }
    }

    func applyReview(_ rating: ReviewRating, to card: KanjiCard) {
        guard !trainingSession.isPreparingCard else {
            return
        }

        Task { @MainActor in
            await applyReviewAndAdvance(rating, to: card)
        }
    }

    func applyReviewAndAdvance(_ rating: ReviewRating, to card: KanjiCard) async {
        let shouldAdvance = applyCurrentItemReview(
            rating: rating,
            expectedKey: card.reviewKey,
            masteredKeys: &trainingSession.masteredKanjiKeys,
            items: &cards
        )

        if !shouldAdvance {
            return
        }

        await advanceToNextKanjiOrFinish()
    }

    func applyCurrentItemReview<Item: StudyItem>(
        rating: ReviewRating,
        expectedKey: String? = nil,
        masteredKeys: inout Set<String>,
        items: inout [Item]
    ) -> Bool {
        guard items.indices.contains(trainingSession.currentIndex), !trainingSession.isPreparingCard else {
            return false
        }

        let item = items[trainingSession.currentIndex]
        if let expectedKey, item.reviewKey != expectedKey {
            return false
        }

        return applyStudyItemReview(
            item,
            rating: rating,
            masteredKeys: &masteredKeys,
            items: &items
        )
    }

    func applyStudyItemReview<Item: StudyItem>(
        _ item: Item,
        rating: ReviewRating,
        masteredKeys: inout Set<String>,
        items: inout [Item]
    ) -> Bool {
        TrainingReviewService.applyReview(
            item: item,
            rating: rating,
            mode: practiceMode,
            session: trainingSession,
            reviewStore: &reviewStore,
            masteredKeys: &masteredKeys,
            items: &items,
            learningSuccessTarget: kanjiLearningSuccessTarget
        )
    }

    func updateFeedback(for card: KanjiCard, reveal: Bool) {
        let shouldReveal = drawingSession.evaluateFeedback(for: card, reveal: reveal)
        if shouldReveal {
            revealDrawingAnswer()
        }
    }
}
