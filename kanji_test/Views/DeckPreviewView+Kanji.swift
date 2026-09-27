import SwiftUI

extension DeckPreviewView {
    func deckPreviewView(for deck: KanjiDeck) -> some View {
        @Bindable var coordinator = coordinator
        let plan = previewPlan(sourceIDs: deckState.previewCards.map(\.id), deck: .kanji(deck))

        return ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                previewHeader(title: deck.title, subtitle: deckPreviewStatus, onBack: exitSelectionOrClose) {
                    if !session.isSelecting {
                        GlassIconButton(systemImage: "info.circle",
                                        accessibilityLabel: "Расписание повторений",
                                        action: { coordinator.isDeckSchedulePresented = true })
                    }

                    GlassIconButton(systemImage: "gearshape",
                                    accessibilityLabel: "Настройки",
                                    action: onOpenSettings)
                }

                if session.isSelecting {
                    CustomSelectionToolbar(session: session, cardIDs: deckState.previewCards.map(\.id))
                        .frame(maxWidth: .infinity, alignment: .trailing)
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
            .padding(.top, 8)
            .foregroundStyle(AppPalette.text)
        }
        .safeAreaInset(edge: .bottom) {
            // Единая нижняя панель: старт колоды или режим выбора карточек
            // занимают одно и то же место с одной и той же геометрией.
            if session.isSelecting {
                CustomSelectionBar(session: session, onStart: onStartCustomTraining, onSearch: { isSearchPresented = true })
            } else {
                BottomActionBar {
                    previewStartButton(
                        plan: plan,
                        isDisabled: deckState.previewCards.isEmpty,
                        action: { onPractice(.kanji(deckState.previewCards, guided: false)) },
                        onCustomTraining: onCustomTraining
                    )

                    GlassIconButton(systemImage: "magnifyingglass",
                                    accessibilityLabel: "Поиск по колоде",
                                    diameter: 52,
                                    accessibilityIdentifier: AccessibilityID.Preview.search,
                                    action: { isSearchPresented = true })
                }
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
