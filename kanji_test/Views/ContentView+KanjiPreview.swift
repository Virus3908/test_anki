import SwiftUI

extension ContentView {
    func kanjiPreviewTile(for card: KanjiCard) -> some View {
        Button {
            openKanjiPreviewCard(card)
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
        NavigationStack {
            ZStack {
                AppPalette.background
                    .ignoresSafeArea()

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        cardBackContent(for: card)
                            .padding(18)
                            .appSurfaceCard()

                        primaryActionButton(title: "Тренировать этот кандзи", systemImage: "pencil.and.scribble") {
                            presentedKanjiPreview = nil
                            selectedPreviewCard = nil
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
            .task(id: "preview-detail-\(card.id)-\(meaningLanguage.rawValue)") {
                await translateKanjiMeaningsIfNeeded(for: card, deck: selectedDeck)
                await translateKanjiExamplesIfNeeded(for: card, deck: selectedDeck)
            }
        }
        .background(AppPalette.background.ignoresSafeArea())
    }

}
