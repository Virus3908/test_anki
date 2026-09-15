import SwiftUI

extension ContentView {
    func kanaPreviewTile(for card: KanaStudyCard) -> some View {
        Button {
            selectedKanaPreviewCard = card
            previewSwipeDirection = 0
            isPreviewDetailPresented = true
        } label: {
            VStack(spacing: 4) {
                Text(card.character)
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .frame(maxWidth: .infinity)
                    .minimumScaleFactor(0.55)

                Text(card.reading)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(height: 14)
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.border.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    func kanaPreviewDetail(for card: KanaStudyCard, deck: KanaDeck) -> some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    kanaPreviewCardContent(for: card)

                    Button {
                        selectedKanaPreviewCard = nil
                        isPreviewDetailPresented = false
                        startKanaTraining(deck: deck, cards: [card], guided: true)
                    } label: {
                        HStack {
                            Image(systemName: "pencil.and.scribble")
                            Text("Тренировать этот знак")
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
            .id(card.character)
            .transition(previewDetailTransition)
            .simultaneousGesture(kanaPreviewCardSwipeGesture(for: card, in: deck))
        }
    }

}
