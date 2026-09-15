import SwiftUI

extension ContentView {
    func wordPreviewTile(for card: WordStudyCard) -> some View {
        Button {
            selectedWordPreviewCard = card
            previewSwipeDirection = 0
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
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    wordFullCard(for: card)

                    primaryActionButton(title: "Практиковать слово", systemImage: "pencil.and.scribble") {
                        selectedWordPreviewCard = nil
                        startWordTraining(with: [card])
                    }
                }
                .padding(20)
            }
            .background(AppPalette.background)
            .id(card.id)
            .transition(previewDetailTransition)
            .simultaneousGesture(wordPreviewCardSwipeGesture(for: card, in: deck))
        }
        .sheet(isPresented: $isLinkedKanjiPresented) {
            selectedLinkedKanjiCard = nil
        } content: {
            if let selectedLinkedKanjiCard {
                kanjiPreviewDetail(for: selectedLinkedKanjiCard)
            }
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
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
                }
                .task(id: "word-example-translation-\(card.id)-\(meaningLanguage.rawValue)-\(sourceExamples.map(\.id).joined(separator: "|"))") {
                    await translateWordExamplesIfNeeded(for: card, examples: sourceExamples)
                }
            }
        } else if loadingWordExampleKeys.contains(card.id) {
            ProgressView("Ищу примеры")
                .font(.caption)
                .foregroundStyle(AppPalette.secondaryText)
                .tint(AppPalette.accent)
        }
    }

    func loadWordUsageExamplesIfNeeded(for card: WordStudyCard) async {
        guard wordUsageExamples[card.id] == nil, !loadingWordExampleKeys.contains(card.id) else {
            return
        }

        loadingWordExampleKeys.insert(card.id)
        let examples = await WordUsageExampleProvider.loadExamples(for: card)
        await MainActor.run {
            wordUsageExamples[card.id] = examples
            loadingWordExampleKeys.remove(card.id)
        }
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
            selectedLinkedKanjiCard = card
            isLinkedKanjiPresented = true
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(card.kanji)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppPalette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(wordComponentSubtitle(for: card))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.border.opacity(0.55), lineWidth: 1)
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
