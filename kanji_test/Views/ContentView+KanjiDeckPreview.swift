import SwiftUI

extension ContentView {
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
                    startRandomTrainingFromPreview()
                }

                ScrollView(.vertical) {
                    LazyVGrid(columns: kanjiPreviewColumns, spacing: 10) {
                        ForEach(deckState.previewCards) { card in
                            kanjiPreviewTile(for: card)
                        }
                    }
                    .padding(.bottom, 20)
                }

                if deckState.isLoadingDeck {
                    ProgressView("Загружаю карточки")
                        .foregroundStyle(AppPalette.secondaryText)
                        .tint(AppPalette.accent)
                }
            }
            .padding(20)
            .foregroundStyle(AppPalette.text)
        }
        .sheet(item: $coordinator.presentedKanjiPreview, onDismiss: {
            coordinator.closeKanjiPreview()
        }) { presentedPreview in
            kanjiPreviewDetail(for: coordinator.selectedPreviewCard ?? presentedPreview.card)
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
