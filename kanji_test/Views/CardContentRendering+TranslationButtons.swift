import SwiftUI

extension CardContentRendering {
    @ViewBuilder
    func retranslateKanjiMeaningsButton(for card: KanjiCard) -> some View {
        if meaningLanguage == .russian {
            let key = TranslationBlockKey.kanjiMeaning(card.kanji)
            translationRetryControls(
                originalText: originalKanjiMeaningsText(for: card),
                isLoading: translationState.isManuallyTranslating(key)
            ) {
                retranslateKanjiMeanings(card, deck: selectedDeck)
            }
        }
    }

    @ViewBuilder
    func retranslateKanjiExamplesButton(for card: KanjiCard) -> some View {
        if meaningLanguage == .russian {
            let key = TranslationBlockKey.kanjiExamples(card.kanji)
            translationRetryControls(
                originalText: originalKanjiExamplesText(for: card),
                isLoading: translationState.isManuallyTranslating(key)
            ) {
                retranslateKanjiExamples(card, deck: selectedDeck)
            }
        }
    }

    func reloadKanjiExamplesButton(for card: KanjiCard) -> some View {
        let key = TranslationBlockKey.kanjiExamples(card.kanji)
        return Button {
            reloadKanjiExamples(card)
        } label: {
            Label(
                translationState.isManuallyReloadingExamples(key) ? "Запрашиваю примеры" : "Перезапросить примеры",
                systemImage: "arrow.clockwise"
            )
            .font(.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.accent)
        .disabled(
            translationState.isManuallyReloadingExamples(key)
                || translationState.isManuallyTranslating(key)
        )
    }

    @ViewBuilder
    func retranslateWordButton(for card: WordStudyCard) -> some View {
        if meaningLanguage == .russian {
            let key = TranslationBlockKey.wordMeaning(card.id)
            translationRetryControls(
                originalText: card.meaning,
                isLoading: translationState.isManuallyTranslating(key)
            ) {
                retranslateWordMeaning(card)
            }
        }
    }

    @ViewBuilder
    func retranslateWordExamplesButton(for card: WordStudyCard) -> some View {
        if meaningLanguage == .russian {
            let key = TranslationBlockKey.wordExamples(card.id)
            translationRetryControls(
                originalText: originalWordExamplesText(for: card),
                isLoading: translationState.isManuallyTranslating(key)
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
