import SwiftUI

extension DeckPreviewView {
    func deckPreviewView(for deck: KanjiDeck) -> some View {
        @Bindable var coordinator = coordinator
        let plan = previewPlan(sourceIDs: deckState.previewCards.map(\.id), deck: .kanji(deck))

        return ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                previewHeader(title: deck.title, subtitle: deckPreviewStatus, onBack: closeDeckPreview) {
                    Button {
                        isSearchPresented = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .tint(AppPalette.accent)

                    if !session.isSelecting {
                        Button {
                            coordinator.isDeckSchedulePresented = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(AppPalette.accent)
                    }
                }

                if session.isSelecting {
                    CustomSelectionToolbar(session: session, cardIDs: deckState.previewCards.map(\.id))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if !session.isSelecting {
                    previewStartButton(
                        plan: plan,
                        isDisabled: deckState.previewCards.isEmpty,
                        action: { onPractice(.kanji(deckState.previewCards, guided: false)) },
                        onCustomTraining: onCustomTraining
                    )
                }

                ScrollView(.vertical) {
                    LazyVGrid(columns: kanjiPreviewColumns, spacing: 10) {
                        ForEach(deckState.previewCards) { card in
                            kanjiPreviewTile(for: card, action: session.isSelecting ? { session.toggle(card.id) } : nil)
                                .cardMasteryChrome(cardMastery(forReviewKey: card.reviewKey))
                                .customSelectionChrome(isSelecting: session.isSelecting,
                                                       isSelected: session.selectedIDs.contains(card.id))
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 44)
                }
                .mask { BottomScrollMask() }
                .frame(maxHeight: .infinity)

                if deckState.isLoadingDeck {
                    CenteredLoadingIndicator(title: "Подготавливаю карточки")
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
        .sheet(item: $coordinator.presentedKanjiPreview, onDismiss: {
            coordinator.closeKanjiPreview()
        }) { presentedPreview in
            if let card = coordinator.catalog.kanji(presentedPreview.cardID) {
                kanjiPreviewDetail(for: coordinator.selectedPreviewCard ?? card)
            }
        }
        .sheet(isPresented: $isSearchPresented) {
            cardSearchSheet(scope: .kanji)
        }
        .sheet(isPresented: $coordinator.isDeckSchedulePresented) {
            deckScheduleInfoView(for: deck)
        }
    }

    var kanjiPreviewColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
    }

    var deckPreviewStatus: String {
        if let previewExpectedCount = deckState.previewExpectedCount {
            return "\(deckState.previewCards.count) / \(previewExpectedCount) карточек"
        }

        return "\(deckState.previewCards.count) карточек"
    }
}
