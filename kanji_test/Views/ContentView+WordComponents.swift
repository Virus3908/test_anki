import SwiftUI

extension ContentView {
    func wordComponentsBlock(for card: WordStudyCard) -> some View {
        detailBlock("Состав") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(card.kanjiCards, id: \.kanji) { kanjiCard in
                    wordComponentLink(for: kanjiCard)
                }
            }
        }
    }

    func wordComponentLink(for card: KanjiCard) -> some View {
        Button {
            coordinator.openLinkedKanjiPreview(card)
        } label: {
            HStack(spacing: 6) {
                Text(card.kanji)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppPalette.text)
                    .lineLimit(1)

                Text("-")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.mutedText)

                Text(wordComponentSubtitle(for: card))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .trailing) {
                LinearGradient(
                    colors: [AppPalette.background.opacity(0), AppPalette.background],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 22)
                .padding(.vertical, 1)
                .allowsHitTesting(false)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(AppPalette.border.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    func wordComponentSubtitle(for card: KanjiCard) -> String {
        if let meaning = displayedKanjiMeanings(for: card).first, !meaning.isEmpty {
            return meaning
        }

        if let reading = card.kunyomi.first ?? card.onyomi.first, !reading.isEmpty {
            return reading
        }

        return "знак"
    }
}
