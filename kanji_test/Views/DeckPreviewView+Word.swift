import SwiftUI

extension DeckPreviewView {
    func wordPreviewView(for deck: WordFrequencyDeck) -> some View {
        @Bindable var coordinator = coordinator
        let plan = previewPlan(sourceIDs: deckState.previewWordCards.map(\.id), deck: .words(deck))

        return ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                previewHeader(title: deck.title, subtitle: wordPreviewStatus, onBack: closeWordPreview) {
                    Button {
                        isSearchPresented = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .tint(AppPalette.accent)
                }

                if session.isSelecting {
                    CustomSelectionToolbar(session: session, cardIDs: deckState.previewWordCards.map(\.id))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if !session.isSelecting {
                    previewStartButton(
                        plan: plan,
                        isDisabled: deckState.previewWordCards.isEmpty,
                        action: { onPractice(.words(deckState.previewWordCards, guided: false)) },
                        onCustomTraining: onCustomTraining
                    )
                }

                ScrollView(.vertical) {
                    LazyVGrid(columns: wordPreviewColumns, spacing: 10) {
                        ForEach(deckState.previewWordCards) { card in
                            wordPreviewTile(for: card, action: session.isSelecting ? { session.toggle(card.id) } : nil)
                                .cardMasteryChrome(session.isSelecting ? cardMastery(forReviewKey: card.reviewKey) : nil)
                                .customSelectionChrome(isSelecting: session.isSelecting,
                                                       isSelected: session.selectedIDs.contains(card.id))
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
        .safeAreaInset(edge: .bottom) {
            if session.isSelecting {
                CustomSelectionBar(session: session, onStart: onStartCustomTraining)
            }
        }
        .sheet(item: $coordinator.presentedWordPreview, onDismiss: {
            coordinator.closeWordPreview()
        }) { presentedPreview in
            if let card = coordinator.catalog.word(presentedPreview.cardID) {
                wordPreviewDetail(for: coordinator.selectedWordPreviewCard ?? card, deck: deck)
            }
        }
        .sheet(isPresented: $isSearchPresented) {
            cardSearchSheet(scope: .words)
        }
    }

    var wordPreviewColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    var wordPreviewStatus: String {
        deckState.isLoadingDeck ? "Загружаю словарь" : "\(deckState.previewWordCards.count) слов"
    }
}
