import SwiftUI

extension CardContentRendering {
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

    func wordFullCardContent(
        for card: WordStudyCard,
        fields: [BuiltInCardField]? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(fields ?? cardFields(for: .words, side: .back)) { field in
                wordCardField(field, for: card)
            }
        }
        .textSelection(.enabled)
        .task(id: "\(card.id)-\(meaningLanguage.rawValue)") {
            await translateWordMeaningIfNeeded(for: card)
        }
    }

    func linkedWordPreviewDetail(for card: WordStudyCard) -> some View {
        NavigationStack {
            ZStack {
                AppPalette.background
                    .ignoresSafeArea()

                ScrollView(.vertical) {
                    wordFullCardContent(
                        for: card,
                        fields: BuiltInCardField.available(for: .words).filter { $0 != .components }
                    )
                        .padding(18)
                        .appSurfaceCard()
                        .padding(20)
                }
            }
            .background(AppPalette.background)
            .foregroundStyle(AppPalette.text)
        }
        .background(AppPalette.background.ignoresSafeArea())
    }

    @ViewBuilder
    func wordCardField(_ field: BuiltInCardField, for card: WordStudyCard) -> some View {
        switch field {
        case .word:
            detailBlock("Слово") {
                Text(card.word)
                    .font(.system(size: 48, weight: .regular, design: .serif))
                    .foregroundStyle(AppPalette.text)
                    .minimumScaleFactor(0.42)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
        case .reading:
            detailBlock("Чтение") {
                Text(card.reading)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity)
            }
        case .meanings:
            translatableTextBlock("Перевод", text: displayedWordMeaning(for: card)) {
                retranslateWordButton(for: card)
            }
        case .components:
            wordComponentsBlock(for: card)
        case .examples:
            wordExamplesBlock(for: card)
        default:
            EmptyView()
        }
    }
}
