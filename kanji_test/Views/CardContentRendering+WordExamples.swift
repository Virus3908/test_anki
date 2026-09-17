import SwiftUI

extension CardContentRendering {
    @ViewBuilder
    func wordExamplesBlock(for card: WordStudyCard) -> some View {
        let key = TranslationBlockKey.wordExamples(card.id)
        let examples = displayedWordUsageExamples(for: card).map { example in
            StudyExample(wordExample: example, reading: wordExampleReading(for: example, card: card))
        }
        detailBlock("Примеры") {
            StudyExamplesContent(
                examples: examples,
                isLoading: translationState.isAutomaticallyLoadingExamples(key)
                    || translationState.isManuallyReloadingExamples(key),
                loadingText: translationState.isManuallyReloadingExamples(key)
                    ? "Запрашиваю примеры"
                    : "Ищу примеры",
                emptyText: "Примеры пока не загружены"
            ) {
                retranslateWordExamplesButton(for: card)
                reloadWordExamplesButton(for: card)
            }
            .task(id: "\(card.id)-\(meaningLanguage.rawValue)") {
                await translationState.loadAndTranslateWordExamples(for: card, language: meaningLanguage)
            }
        }
    }

    func reloadWordUsageExamples(for card: WordStudyCard) {
        translationState.reloadWordUsageExamples(for: card, language: meaningLanguage)
    }

    func reloadWordExamplesButton(for card: WordStudyCard) -> some View {
        let key = TranslationBlockKey.wordExamples(card.id)
        return Button {
            reloadWordUsageExamples(for: card)
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

struct StudyExamplesContent<Controls: View>: View {
    let examples: [StudyExample]
    let isLoading: Bool
    let loadingText: String
    let emptyText: String
    let controls: Controls

    init(
        examples: [StudyExample],
        isLoading: Bool,
        loadingText: String,
        emptyText: String,
        @ViewBuilder controls: () -> Controls
    ) {
        self.examples = examples
        self.isLoading = isLoading
        self.loadingText = loadingText
        self.emptyText = emptyText
        self.controls = controls()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if examples.isEmpty {
                if isLoading {
                    ProgressView(loadingText)
                        .font(.caption)
                        .foregroundStyle(AppPalette.secondaryText)
                        .tint(AppPalette.accent)
                } else {
                    Text(emptyText)
                        .font(.caption)
                        .foregroundStyle(AppPalette.secondaryText)
                }
            } else {
                ForEach(Array(examples.enumerated()), id: \.offset) { _, example in
                    StudyExampleRow(example: example)
                }
            }

            controls
        }
    }
}

private struct StudyExampleRow: View {
    let example: StudyExample

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(example.text)
                .foregroundStyle(AppPalette.text)
                .fixedSize(horizontal: false, vertical: true)

            if let reading = example.reading {
                Text(reading)
                    .font(.caption)
                    .foregroundStyle(AppPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let meaning = example.meaning {
                Text(meaning)
                    .font(.caption)
                    .foregroundStyle(AppPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
