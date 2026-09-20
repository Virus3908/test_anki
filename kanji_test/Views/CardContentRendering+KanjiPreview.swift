import SwiftUI

extension CardContentRendering {
    /// `action` переопределяет нажатие — например, поиск открывает
    /// linked-превью вместо обычного превью колоды.
    func kanjiPreviewTile(for card: KanjiCard, action: (() -> Void)? = nil) -> some View {
        Button {
            if let action {
                action()
            } else {
                openKanjiPreviewCard(card)
            }
        } label: {
            VStack(spacing: 6) {
                Text(card.kanji)
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .frame(maxWidth: .infinity)

                Text(displayedKanjiMeanings(for: card).prefix(2).joined(separator: ", "))
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppPalette.secondaryText)
                    .frame(height: 28, alignment: .top)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 86)
            .appSurfaceCard(borderOpacity: 0.55)
        }
        .buttonStyle(.plain)
        .task(id: "preview-meaning-\(card.id)-\(meaningLanguage.rawValue)") {
            await translateKanjiMeaningsIfNeeded(for: card, deck: selectedDeck)
        }
    }

    func kanjiPreviewDetail(for card: KanjiCard) -> some View {
        @Bindable var coordinator = coordinator

        return NavigationStack {
            ZStack {
                AppPalette.background
                    .ignoresSafeArea()

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        cardBackContent(for: card, fields: BuiltInCardField.available(for: .kanji))
                            .padding(18)
                            .appSurfaceCard()

                        primaryActionButton(title: "Тренировать этот кандзи", systemImage: "pencil.and.scribble") {
                            coordinator.closeKanjiPreview()
                            startTraining(with: [card], guided: true)
                        }
                    }
                    .padding(20)
                    .id(card.kanji)
                    .transition(previewDetailTransition)
                }
            }
            .background(AppPalette.background)
            .foregroundStyle(AppPalette.text)
            .simultaneousGesture(previewCardSwipeGesture(for: card))
        }
        .background(AppPalette.background.ignoresSafeArea())
        .sheet(item: $coordinator.selectedLinkedWordCard, onDismiss: {
            coordinator.closeLinkedWordPreview()
        }) { word in
            linkedWordPreviewDetail(for: word)
        }
        .sheet(item: $coordinator.selectedRelatedWordsKanjiCard, onDismiss: {
            coordinator.closeRelatedWordsList()
        }) { selectedCard in
            allRelatedWordsList(for: selectedCard)
        }
    }

    func linkedWordKanjiPreviewDetail(for card: KanjiCard) -> some View {
        NavigationStack {
            ZStack {
                AppPalette.background
                    .ignoresSafeArea()

                ScrollView(.vertical) {
                    cardBackContent(
                        for: card,
                        fields: BuiltInCardField.available(for: .kanji).filter { $0 != .relatedWords }
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

}
