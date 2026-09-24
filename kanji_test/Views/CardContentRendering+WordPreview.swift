import SwiftUI

extension CardContentRendering {
    /// `action` переопределяет нажатие — например, поиск открывает
    /// linked-превью вместо обычного превью колоды.
    func wordPreviewTile(for card: WordStudyCard, action: (() -> Void)? = nil) -> some View {
        Button {
            if let action {
                action()
            } else {
                openWordPreviewCard(card)
            }
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
        VStack(alignment: .leading, spacing: 16) {
            BuiltInCardPreviewActions(
                speechText: card.word,
                settings: settings,
                deckID: deckID,
                mode: .words
            )
            wordFullCardContent(for: card, fields: BuiltInCardField.available(for: .words))
            learningStatusLabel(forReviewKey: card.reviewKey)
        }
            .padding(18)
            .appSurfaceCard()
    }

    func wordFullCardContent(
        for card: WordStudyCard,
        fields: [BuiltInCardField]? = nil,
        onOpenKanji: ((KanjiCard) -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(fields ?? cardFields(for: .words, side: .back)) { field in
                wordCardField(field, for: card, onOpenKanji: onOpenKanji)
            }
        }
        .textSelection(.enabled)
        .task(id: "\(card.id)-\(meaningLanguage.rawValue)") {
            await translateWordMeaningIfNeeded(for: card)
        }
    }

    func linkedWordPreviewDetail(for card: WordStudyCard) -> some View {
        @Bindable var coordinator = coordinator

        return NavigationStack {
            ZStack {
                AppPalette.background
                    .ignoresSafeArea()

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 14) {
                        BuiltInCardPreviewActions(
                            speechText: card.word,
                            settings: settings,
                            deckID: deckID,
                            mode: .words
                        )
                        wordFullCardContent(
                            for: card,
                            fields: BuiltInCardField.available(for: .words),
                            onOpenKanji: coordinator.openLinkedWordKanjiPreview
                        )
                    }
                        .padding(18)
                        .appSurfaceCard()
                        .padding(20)
                }
            }
            .background(AppPalette.background)
            .foregroundStyle(AppPalette.text)
        }
        .background(AppPalette.background.ignoresSafeArea())
        .sheet(item: $coordinator.selectedLinkedWordKanjiCard, onDismiss: {
            coordinator.closeLinkedWordKanjiPreview()
        }) { kanji in
            linkedWordKanjiPreviewDetail(for: kanji)
        }
    }

    @ViewBuilder
    func wordCardField(
        _ field: BuiltInCardField,
        for card: WordStudyCard,
        onOpenKanji: ((KanjiCard) -> Void)? = nil
    ) -> some View {
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
            wordComponentsBlock(for: card, onOpenKanji: onOpenKanji)
        case .examples:
            wordExamplesBlock(for: card)
        default:
            EmptyView()
        }
    }
}
