import SwiftUI

extension ContentView {
    func wordPreviewTile(for card: WordStudyCard) -> some View {
        Button {
            openWordPreviewCard(card)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.reading)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(card.word)
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Text(displayedWordMeaning(for: card))
                    .font(.caption)
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .appSurfaceCard(borderOpacity: 0.55)
        }
        .buttonStyle(.plain)
    }

    func wordPreviewDetail(for card: WordStudyCard, deck: WordFrequencyDeck) -> some View {
        NavigationStack {
            ZStack {
                AppPalette.background
                    .ignoresSafeArea()

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        wordFullCard(for: card)

                        primaryActionButton(title: "Практиковать слово", systemImage: "pencil.and.scribble") {
                            coordinator.presentedWordPreview = nil
                            coordinator.selectedWordPreviewCard = nil
                            startWordTraining(with: [card], guided: true)
                        }
                    }
                    .padding(20)
                    .id(card.id)
                    .transition(previewDetailTransition)
                }
            }
            .background(AppPalette.background)
            .simultaneousGesture(wordPreviewCardSwipeGesture(for: card, in: deck))
        }
        .background(AppPalette.background.ignoresSafeArea())
        .sheet(item: $coordinator.selectedLinkedKanjiCard, onDismiss: {
            coordinator.selectedLinkedKanjiCard = nil
        }) { card in
            kanjiPreviewDetail(for: card)
        }
    }

    func wordFullCard(for card: WordStudyCard) -> some View {
        wordFullCardContent(for: card)
            .padding(18)
            .appSurfaceCard()
    }

    func wordFullCardContent(for card: WordStudyCard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 6) {
                Text(card.word)
                    .font(.system(size: 64, weight: .regular, design: .serif))
                    .foregroundStyle(AppPalette.text)
                    .minimumScaleFactor(0.42)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                Text(card.reading)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)

            detailBlock("Перевод") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(displayedWordMeaning(for: card))
                        .foregroundStyle(AppPalette.text)
                        .fixedSize(horizontal: false, vertical: true)

                    retranslateWordButton(for: card)
                }
            }

            detailBlock("Состав") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(card.kanjiCards.indices, id: \.self) { index in
                        wordComponentLink(for: card.kanjiCards[index])
                    }
                }
            }

            wordExamplesBlock(for: card)
        }
        .textSelection(.enabled)
        .task(id: "\(card.id)-\(meaningLanguage.rawValue)") {
            await translateWordMeaningIfNeeded(for: card)
        }
        .task(id: "word-examples-\(card.id)") {
            await loadWordUsageExamplesIfNeeded(for: card)
        }
    }

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
                .task(id: "word-example-translation-\(card.id)-\(meaningLanguage.rawValue)-\(sourceExamples.map(\.id).joined(separator: "|"))") {
                    await translateWordExamplesIfNeeded(for: card, examples: sourceExamples)
                }
            }
        } else if translationState.loadingWordExampleKeys.contains(card.id) {
            ProgressView("Ищу примеры")
                .font(.caption)
                .foregroundStyle(AppPalette.secondaryText)
                .tint(AppPalette.accent)
        } else {
            detailBlock("Примеры") {
                reloadWordExamplesButton(for: card)
            }
        }
    }

    func loadWordUsageExamplesIfNeeded(for card: WordStudyCard) async {
        guard translationState.wordUsageExamples[card.id] == nil, !translationState.loadingWordExampleKeys.contains(card.id) else {
            return
        }

        translationState.loadingWordExampleKeys.insert(card.id)
        let examples = await WordUsageExampleProvider.loadExamples(for: card)
        await MainActor.run {
            translationState.wordUsageExamples[card.id] = examples
            translationState.loadingWordExampleKeys.remove(card.id)
        }
    }

    func reloadWordUsageExamples(for card: WordStudyCard) {
        guard !translationState.loadingWordExampleKeys.contains(card.id) else {
            return
        }

        translationState.loadingWordExampleKeys.insert(card.id)

        Task { @MainActor in
            let examples = await WordUsageExampleProvider.reloadRemoteExamples(for: card)
            if !examples.isEmpty {
                translationState.wordUsageExamples[card.id] = examples
                translationState.wordExampleTranslations[card.id] = nil

                if meaningLanguage == .russian {
                    let translatedExamples = await translateWordUsageExamples(examples)
                    translationState.wordExampleTranslations[card.id] = translatedExamples
                    KanjiTranslationStore.saveWordExampleTranslation(translatedExamples, for: card.id)
                }
            }

            translationState.loadingWordExampleKeys.remove(card.id)
        }
    }

    func reloadWordExamplesButton(for card: WordStudyCard) -> some View {
        Button {
            reloadWordUsageExamples(for: card)
        } label: {
            Label(
                translationState.loadingWordExampleKeys.contains(card.id) ? "Запрашиваю примеры" : "Перезапросить примеры",
                systemImage: "arrow.clockwise"
            )
            .font(.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.accent)
        .disabled(translationState.loadingWordExampleKeys.contains(card.id))
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

    func wordComponentLink(for card: KanjiCard) -> some View {
        Button {
            coordinator.selectedLinkedKanjiCard = card
        } label: {
            HStack(spacing: 6) {
                Text(card.kanji)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppPalette.text)
                    .lineLimit(1)

                Text("-")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.mutedText)

                Text(wordComponentSubtitle(for: card))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .trailing) {
                LinearGradient(
                    colors: [AppPalette.background.opacity(0), AppPalette.background],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 22)
                .padding(.vertical, 1)
                .allowsHitTesting(false)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(AppPalette.border.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    func wordComponentSubtitle(for card: KanjiCard) -> String {
        if let meaning = displayedKanjiMeanings(for: card).first, !meaning.isEmpty {
            return meaning
        }

        if let reading = card.kunyomi.first ?? card.onyomi.first, !reading.isEmpty {
            return reading
        }

        return "знак"
    }

}
