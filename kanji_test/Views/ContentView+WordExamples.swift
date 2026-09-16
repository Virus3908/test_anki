import SwiftUI

extension ContentView {
    @ViewBuilder
    func wordExamplesBlock(for card: WordStudyCard) -> some View {
        let sourceExamples = originalWordUsageExamples(for: card)
        let examples = displayedWordUsageExamples(for: card)
        if !examples.isEmpty {
            detailBlock("Примеры") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(examples) { example in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(example.sentence)
                                .foregroundStyle(AppPalette.text)
                                .fixedSize(horizontal: false, vertical: true)

                            if let reading = wordExampleReading(for: example, card: card) {
                                Text(reading)
                                    .font(.caption)
                                    .foregroundStyle(AppPalette.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if let meaning = example.meaning, !meaning.isEmpty {
                                Text(meaning)
                                    .font(.caption)
                                    .foregroundStyle(AppPalette.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    retranslateWordExamplesButton(for: card)
                    reloadWordExamplesButton(for: card)
                }
                .task(id: "\(card.id)-\(meaningLanguage.rawValue)-\(sourceExamples.map(\.id).joined(separator: "|"))") {
                    await translateWordExamplesIfNeeded(for: card, examples: sourceExamples)
                }
            }
        } else if translationState.loadingWordExampleKeys.contains(card.id) || translationState.reloadingWordExampleKeys.contains(card.id) {
            detailBlock("Примеры") {
                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(translationState.reloadingWordExampleKeys.contains(card.id) ? "Запрашиваю примеры" : "Ищу примеры")
                        .font(.caption)
                        .foregroundStyle(AppPalette.secondaryText)
                        .tint(AppPalette.accent)

                    reloadWordExamplesButton(for: card)
                }
            }
        } else {
            detailBlock("Примеры") {
                reloadWordExamplesButton(for: card)
            }
        }
    }

    func loadWordUsageExamplesIfNeeded(for card: WordStudyCard) async {
        await translationState.loadWordUsageExamplesIfNeeded(for: card)
    }

    func reloadWordUsageExamples(for card: WordStudyCard) {
        translationState.reloadWordUsageExamples(for: card, language: meaningLanguage)
    }

    func reloadWordExamplesButton(for card: WordStudyCard) -> some View {
        Button {
            reloadWordUsageExamples(for: card)
        } label: {
            Label(
                translationState.reloadingWordExampleKeys.contains(card.id) ? "Запрашиваю примеры" : "Перезапросить примеры",
                systemImage: "arrow.clockwise"
            )
            .font(.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.accent)
        .disabled(
            translationState.reloadingWordExampleKeys.contains(card.id)
                || translationState.retranslationWordExampleKeys.contains(card.id)
        )
    }

    func wordExampleReading(for example: WordUsageExample, card: WordStudyCard) -> String? {
        if let reading = example.reading?.trimmingCharacters(in: .whitespacesAndNewlines), !reading.isEmpty {
            return reading
        }

        guard card.word != card.reading, example.sentence.contains(card.word) else {
            return nil
        }

        return "\(card.word): \(card.reading)"
    }
}
