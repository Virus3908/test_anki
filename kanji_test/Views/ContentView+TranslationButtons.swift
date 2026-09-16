import SwiftUI

extension ContentView {
    @ViewBuilder
    func retranslateKanjiMeaningsButton(for card: KanjiCard) -> some View {
        if meaningLanguage == .russian {
            translationRetryControls(
                originalText: originalKanjiMeaningsText(for: card),
                isLoading: translationState.retranslationKanjiMeaningKeys.contains(card.kanji)
            ) {
                retranslateKanjiMeanings(card, deck: selectedDeck)
            }
        }
    }

    @ViewBuilder
    func retranslateKanjiExamplesButton(for card: KanjiCard) -> some View {
        if meaningLanguage == .russian {
            translationRetryControls(
                originalText: originalKanjiExamplesText(for: card),
                isLoading: translationState.retranslationKanjiExampleKeys.contains(card.kanji)
            ) {
                retranslateKanjiExamples(card, deck: selectedDeck)
            }
        }
    }

    func reloadKanjiExamplesButton(for card: KanjiCard) -> some View {
        Button {
            reloadKanjiExamples(card)
        } label: {
            Label(
                translationState.reloadingKanjiExampleKeys.contains(card.kanji) ? "Запрашиваю примеры" : "Перезапросить примеры",
                systemImage: "arrow.clockwise"
            )
            .font(.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.accent)
        .disabled(
            translationState.reloadingKanjiExampleKeys.contains(card.kanji)
                || translationState.retranslationKanjiExampleKeys.contains(card.kanji)
        )
    }

    @ViewBuilder
    func retranslateWordButton(for card: WordStudyCard) -> some View {
        if meaningLanguage == .russian {
            translationRetryControls(
                originalText: card.meaning,
                isLoading: translationState.retranslationWordKeys.contains(card.id)
            ) {
                retranslateWordMeaning(card)
            }
        }
    }

    @ViewBuilder
    func retranslateWordExamplesButton(for card: WordStudyCard) -> some View {
        if meaningLanguage == .russian {
            translationRetryControls(
                originalText: originalWordExamplesText(for: card),
                isLoading: translationState.retranslationWordExampleKeys.contains(card.id)
            ) {
                retranslateWordExamples(card)
            }
        }
    }

    func translationRetryControls(
        originalText: String,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        TranslationRetryControls(
            originalText: originalText,
            isLoading: isLoading,
            action: action
        )
    }
}
