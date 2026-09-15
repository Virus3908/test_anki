import SwiftUI

extension ContentView {
    func kanaDeckButton(for deck: KanaDeck) -> some View {
        deckSelectionButton(
            title: deck.title,
            subtitle: "\(deck.cards.count) карточек"
        ) {
            openKanaPreview(deck)
        }
    }

    func deckButton(for deck: KanjiDeck) -> some View {
        deckSelectionButton(
            title: deck.title,
            subtitle: deck.endpointPath
        ) {
            selectedDeck = deck
            openDeckPreview(deck)
        }
    }

    func wordDeckButton(for deck: WordFrequencyDeck) -> some View {
        deckSelectionButton(
            title: deck.title,
            subtitle: deck.subtitle
        ) {
            openWordPreview(deck)
        }
    }

    func deckSelectionButton(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppPalette.secondaryText)
                }

                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .appSurfaceCard()
        }
        .buttonStyle(.plain)
        .disabled(deckState.isLoadingDeck)
    }

}
