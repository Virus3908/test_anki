import SwiftUI

extension DeckPreviewView {
    func wordPreviewView(for deck: WordFrequencyDeck) -> some View {
        @Bindable var coordinator = coordinator
        let plan = previewPlan(sourceIDs: deckState.previewWordCards.map(\.id), deck: .words(deck))

        return ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                previewHeader(title: deck.title, subtitle: wordPreviewStatus, onBack: closeWordPreview)

                previewStartButton(plan: plan, isDisabled: deckState.previewWordCards.isEmpty) {
                    onPractice(.words(deckState.previewWordCards, guided: false))
                }

                ScrollView(.vertical) {
                    LazyVGrid(columns: wordPreviewColumns, spacing: 10) {
                        ForEach(deckState.previewWordCards) { card in
                            wordPreviewTile(for: card)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 44)
                }
                .mask { BottomScrollMask() }
                .frame(maxHeight: .infinity)

                if let error = deckState.loadError {
                    Text(error).font(.caption).foregroundStyle(AppPalette.correction)
                    Button("Повторить") { deckState.openWordPreview(deck) }
                }
                if deckState.isLoadingDeck {
                    CenteredLoadingIndicator(title: "Загружаю слова")
                        .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 20)
            .padding(.bottom, 4)
            .foregroundStyle(AppPalette.text)
        }
        .sheet(item: $coordinator.presentedWordPreview, onDismiss: {
            coordinator.closeWordPreview()
        }) { presentedPreview in
            if let card = coordinator.catalog.word(presentedPreview.cardID) {
                wordPreviewDetail(for: coordinator.selectedWordPreviewCard ?? card, deck: deck)
            }
        }
    }

    var wordPreviewColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    var wordPreviewStatus: String {
        deckState.isLoadingDeck ? "Загружаю словарь" : "\(deckState.previewWordCards.count) слов"
    }
}
