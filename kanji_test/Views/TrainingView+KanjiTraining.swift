import SwiftUI

extension TrainingView {
    func studyCard(for card: KanjiCard) -> some View {
        KanjiTrainingCardView(training: self, card: card)
    }

    func cardFront(for card: KanjiCard) -> some View {
        studyCardFrontShell(
            fallbackPrompt: "Нарисуй кандзи по памяти.",
            footerText: "Проверка покажет оригинал и сравнение штрихов.",
            reviewKey: card.reviewKey
        ) {
            frontFields(for: card)
        }
    }

    @ViewBuilder
    func frontFields(for card: KanjiCard) -> some View {
        kanjiCardFields(cardFields(for: .kanji, side: .front), for: card)
    }
}

private struct KanjiTrainingCardView: View {
    let training: TrainingView
    let card: KanjiCard

    var body: some View {
        training.trainingCardShell {
            training.cardFront(for: card)
        } back: {
            training.cardBackContent(for: card) {
                training.presentCardFieldSettings(side: .back)
            }
        }
        .task(id: "back-\(card.id)-\(training.meaningLanguage.rawValue)") {
            await training.translateKanjiMeaningsIfNeeded(for: card, deck: training.selectedDeck)
        }
    }
}
