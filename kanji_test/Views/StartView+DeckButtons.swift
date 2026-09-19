import SwiftUI

extension StartView {
    func kanaDeckButton(for deck: KanaDeck) -> some View {
        deckSelectionButton(
            title: deck.title,
            subtitle: "\(deck.cards.count) карточек", isDisabled: isLoading
        ) {
            onOpen(.kanaDeck(deck))
        }
    }

    func deckButton(for deck: KanjiDeck) -> some View {
        deckSelectionButton(
            title: deck.title,
            subtitle: deck.endpointPath,
            isDisabled: isLoading
        ) {
            onOpen(.kanjiDeck(deck))
        }
    }

    func wordDeckButton(for deck: WordFrequencyDeck) -> some View {
        deckSelectionButton(
            title: deck.title,
            subtitle: deck.subtitle, isDisabled: isLoading
        ) {
            onOpen(.wordDeck(deck))
        }
    }

}

extension StudyViewStyling {
    func deckSelectionButton(title: String, subtitle: String, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
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
        .disabled(isDisabled)
    }

}
