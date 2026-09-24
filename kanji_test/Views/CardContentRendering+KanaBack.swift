import SwiftUI

extension CardContentRendering {
    func kanaPreviewCardContent(for kanaCard: KanaStudyCard) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            BuiltInCardPreviewActions(
                speechText: kanaCard.character,
                settings: settings,
                deckID: deckID,
                mode: .kana
            )
            kanaCardBackContent(for: kanaCard, fields: BuiltInCardField.available(for: .kana))
        }
            .padding(18)
            .appSurfaceCard()
    }

    func kanaCardBackContent(
        for kanaCard: KanaStudyCard,
        fields: [BuiltInCardField]? = nil,
        onShowAllFields: (() -> Void)? = nil,
        onSpeak: (() -> Void)? = nil
    ) -> some View {
        studyCardBackShell(
            reviewKey: kanaCard.reviewKey,
            isTextSelectable: false,
            onShowAllFields: onShowAllFields,
            onSpeak: onSpeak
        ) {
            ForEach(fields ?? cardFields(for: .kana, side: .back)) { field in
                kanaCardField(field, for: kanaCard)
            }
        }
    }

    @ViewBuilder
    func kanaCardField(_ field: BuiltInCardField, for card: KanaStudyCard) -> some View {
        switch field {
        case .character:
            detailBlock("Кана") {
                Text(card.character)
                    .font(.system(size: 58, weight: .regular, design: .serif))
                    .foregroundStyle(AppPalette.text)
            }
        case .reading:
            detailBlock("Чтение") {
                Text(card.reading).foregroundStyle(AppPalette.text)
            }
        case .strokeCount:
            detailBlock("Число штрихов") {
                Text("\(card.strokes.count)").foregroundStyle(AppPalette.text)
            }
        case .strokeOrder:
            if !card.strokes.isEmpty {
                detailBlock("Порядок штрихов") {
                    StrokeStepStrip(strokes: card.strokes)
                }
            }
        default:
            EmptyView()
        }
    }
}
