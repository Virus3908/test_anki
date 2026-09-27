import SwiftUI

extension DeckPreviewView {
    func kanaPreviewView(for deck: KanaDeck) -> some View {
        @Bindable var coordinator = coordinator
        let plan = previewPlan(sourceIDs: deckState.previewKanaCards.map(\.id), deck: .kana(deck))

        return ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                previewHeader(title: deck.title, subtitle: kanaPreviewStatus(for: deck), onBack: exitSelectionOrClose) {
                    GlassIconButton(systemImage: "gearshape",
                                    accessibilityLabel: "Настройки",
                                    action: onOpenSettings)
                }

                if session.isSelecting {
                    CustomSelectionToolbar(session: session, cardIDs: deckState.previewKanaCards.map(\.id))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                ScrollView(.vertical) {
                    LazyVGrid(columns: kanaPreviewColumns, spacing: 10) {
                        ForEach(deckState.previewKanaCards) { card in
                            kanaPreviewTile(for: card, action: session.isSelecting ? { session.toggle(card.id) } : nil)
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
                    ProgressView("Загружаю штрихи")
                        .foregroundStyle(AppPalette.secondaryText)
                        .tint(AppPalette.accent)
                }

            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .foregroundStyle(AppPalette.text)
        }
        .safeAreaInset(edge: .bottom) {
            // Единая нижняя панель: старт колоды или режим выбора карточек
            // занимают одно и то же место с одной и той же геометрией.
            if session.isSelecting {
                CustomSelectionBar(session: session, onStart: onStartCustomTraining)
            } else {
                BottomActionBar {
                    previewStartButton(
                        plan: plan,
                        isDisabled: deckState.previewKanaCards.isEmpty,
                        action: { onPractice(.kana(deck, deckState.previewKanaCards, guided: false)) },
                        onCustomTraining: onCustomTraining
                    )
                }
            }
        }
        .sheet(item: $coordinator.presentedKanaPreview, onDismiss: {
            coordinator.closeKanaPreview()
        }) { presentedPreview in
            if let card = coordinator.catalog.kana(presentedPreview.cardID) {
                kanaPreviewDetail(for: coordinator.selectedKanaPreviewCard ?? card, deck: deck)
            }
        }
    }

    var kanaPreviewColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
    }

    func kanaPreviewStatus(for deck: KanaDeck) -> String {
        deckState.isLoadingDeck ? "Загружаю штрихи из KanjiVG" : "\(deckState.previewKanaCards.count) карточек из KanjiVG"
    }
}
