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
        @Bindable var coordinator = coordinator

        return NavigationStack {
            ZStack {
                AppPalette.background
                    .ignoresSafeArea()

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        wordFullCard(for: card)

                        primaryActionButton(title: "Практиковать слово", systemImage: "pencil.and.scribble") {
                            coordinator.closeWordPreview()
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
            coordinator.closeLinkedKanjiPreview()
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

            translatableTextBlock("Перевод", text: displayedWordMeaning(for: card)) {
                retranslateWordButton(for: card)
            }

            wordComponentsBlock(for: card)

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

}
