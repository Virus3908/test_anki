import SwiftUI

extension CardContentRendering {
    /// `action` переопределяет нажатие — например, выбор карточки
    /// для кастом-тренировки вместо открытия превью.
    func kanaPreviewTile(for card: KanaStudyCard, action: (() -> Void)? = nil) -> some View {
        Button {
            if let action {
                action()
            } else {
                openKanaPreviewCard(card)
            }
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
            .appSurfaceCard(borderOpacity: 0.55)
        }
        .buttonStyle(.plain)
    }

    func kanaPreviewDetail(for card: KanaStudyCard, deck: KanaDeck) -> some View {
        NavigationStack {
            ZStack {
                AppPalette.background
                    .ignoresSafeArea()

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        kanaPreviewCardContent(for: card)

                        primaryActionButton(title: "Тренировать этот знак", systemImage: "pencil.and.scribble") {
                            coordinator.closeKanaPreview()
                            startKanaTraining(deck: deck, cards: [card], guided: true)
                        }
                    }
                    .padding(20)
                    .id(card.character)
                    .transition(previewDetailTransition)
                }
            }
            .background(AppPalette.background)
            .foregroundStyle(AppPalette.text)
            .simultaneousGesture(kanaPreviewCardSwipeGesture(for: card, in: deck))
        }
        .background(AppPalette.background.ignoresSafeArea())
    }

}
