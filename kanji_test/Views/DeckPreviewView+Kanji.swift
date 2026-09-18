import SwiftUI

extension DeckPreviewView {
    func deckPreviewView(for deck: KanjiDeck) -> some View {
        @Bindable var coordinator = coordinator

        return ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                previewHeader(title: deck.title, subtitle: deckPreviewStatus, onBack: closeDeckPreview) {
                    Button {
                        coordinator.isDeckSchedulePresented = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(AppPalette.accent)
                }

                previewStartButton(count: deckState.previewCards.count, isDisabled: deckState.previewCards.isEmpty) {
                    onPractice(.kanji(deckState.previewCards, guided: false))
                }

                ScrollView(.vertical) {
                    LazyVGrid(columns: kanjiPreviewColumns, spacing: 10) {
                        ForEach(deckState.previewCards) { card in
                            kanjiPreviewTile(for: card)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 44)
                }
                .mask { BottomScrollMask() }
                .frame(maxHeight: .infinity)

                if deckState.isLoadingDeck {
                    CenteredLoadingIndicator(title: "Загружаю карточки")
                        .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 20)
            .padding(.bottom, 4)
            .foregroundStyle(AppPalette.text)
        }
        .sheet(item: $coordinator.presentedKanjiPreview, onDismiss: {
            coordinator.closeKanjiPreview()
        }) { presentedPreview in
            if let card = coordinator.catalog.kanji(presentedPreview.cardID) {
                kanjiPreviewDetail(for: coordinator.selectedPreviewCard ?? card)
            }
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
            return "\(deckState.previewCards.count) / \(previewExpectedCount) загружено"
        }

        return "\(deckState.previewCards.count) загружено"
    }
}
