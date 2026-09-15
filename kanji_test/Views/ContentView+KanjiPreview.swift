import SwiftUI

extension ContentView {
    func kanjiPreviewTile(for card: KanjiCard) -> some View {
        Button {
            selectedPreviewCard = card
            previewSwipeDirection = 0
            isPreviewDetailPresented = true
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
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.border.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .task(id: "preview-meaning-\(card.id)-\(meaningLanguage.rawValue)") {
            await translateKanjiMeaningsIfNeeded(for: card, deck: selectedDeck)
        }
    }

    func kanjiPreviewDetail(for card: KanjiCard) -> some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    cardBackContent(for: card)
                        .padding(18)
                        .background(AppPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppPalette.border.opacity(0.65), lineWidth: 1)
                        )

                    Button {
                        selectedPreviewCard = nil
                        isPreviewDetailPresented = false
                        startTraining(with: [card], guided: true)
                    } label: {
                        HStack {
                            Image(systemName: "pencil.and.scribble")
                            Text("Тренировать этот кандзи")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.accent)
                }
                .padding(20)
            }
            .background(AppPalette.background)
            .foregroundStyle(AppPalette.text)
            .id(card.kanji)
            .transition(previewDetailTransition)
            .simultaneousGesture(previewCardSwipeGesture(for: card))
            .task(id: "preview-detail-\(card.id)-\(meaningLanguage.rawValue)") {
                await translateKanjiMeaningsIfNeeded(for: card, deck: selectedDeck)
                await translateKanjiExamplesIfNeeded(for: card, deck: selectedDeck)
            }
        }
    }

}
