import SwiftUI

extension CardContentRendering {
    func kanaPreviewCardContent(for kanaCard: KanaStudyCard) -> some View {
        kanaCardBackContent(for: kanaCard)
            .padding(18)
            .appSurfaceCard()
    }

    func kanaCardBackContent(for kanaCard: KanaStudyCard) -> some View {
        studyCardBackShell(reviewKey: kanaCard.reviewKey, isTextSelectable: false) {
            HStack(alignment: .top, spacing: 18) {
                largeCharacterPanel(kanaCard.character)

                VStack(alignment: .leading, spacing: 8) {
                    detailBlock("Кана") {
                        Text(kanaCard.character)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppPalette.text)
                    }

                    detailBlock("Чтение") {
                        Text(kanaCard.reading)
                            .foregroundStyle(AppPalette.text)
                    }

                    detailBlock("Штрихи") {
                        Text("\(kanaCard.strokes.count)")
                            .foregroundStyle(AppPalette.text)
                    }
                }
            }

            if !kanaCard.strokes.isEmpty {
                detailBlock("Порядок штрихов") {
                    StrokeStepStrip(strokes: kanaCard.strokes)
                }
            }
        }
    }

}
