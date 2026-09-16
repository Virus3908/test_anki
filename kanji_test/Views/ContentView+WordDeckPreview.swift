import SwiftUI

extension ContentView {
    func wordPreviewView(for deck: WordFrequencyDeck) -> some View {
        @Bindable var coordinator = coordinator

        return ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                previewHeader(title: deck.title, subtitle: wordPreviewStatus, onBack: closeWordPreview)

                previewStartButton(count: deckState.previewWordCards.count, isDisabled: deckState.previewWordCards.isEmpty) {
                    startWordTraining(
                        with: nextWordSessionCards(from: deckState.previewWordCards),
                        sourceCards: deckState.previewWordCards
                    )
                }

                ScrollView(.vertical) {
                    LazyVGrid(columns: wordPreviewColumns, spacing: 10) {
                        ForEach(deckState.previewWordCards) { card in
                            wordPreviewTile(for: card)
                        }
                    }
                    .padding(.bottom, 20)
                }

                if deckState.isLoadingDeck {
                    ProgressView("Загружаю слова")
                        .foregroundStyle(AppPalette.secondaryText)
                        .tint(AppPalette.accent)
                }
            }
            .padding(20)
            .foregroundStyle(AppPalette.text)
        }
        .sheet(item: $coordinator.presentedWordPreview, onDismiss: {
            coordinator.closeWordPreview()
        }) { presentedPreview in
            wordPreviewDetail(for: coordinator.selectedWordPreviewCard ?? presentedPreview.card, deck: deck)
        }
    }

    var wordPreviewColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    var wordPreviewStatus: String {
        deckState.isLoadingDeck ? "Загружаю словарь" : "\(deckState.previewWordCards.count) слов"
    }
}
