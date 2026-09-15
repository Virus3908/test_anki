import SwiftUI

extension ContentView {
    func kanaStudyCard(for kanaCard: KanaStudyCard) -> some View {
        trainingCardShell {
            kanaCardFront(for: kanaCard)
        } back: {
            kanaCardBackContent(for: kanaCard)
        }
    }

    func kanaCardFront(for kanaCard: KanaStudyCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Задание")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.secondaryText)
                .textCase(.uppercase)

            detailBlock("Чтение") {
                Text(kanaCard.reading)
                    .font(.largeTitle.weight(.bold))
            }

            Spacer(minLength: 16)

            Text("Нарисуй знак каны по памяти.")
                .font(.title2.weight(.semibold))

            Text("Проверка покажет оригинал и сравнение штрихов.")
                .foregroundStyle(AppPalette.secondaryText)

            learningStatusLabel(forReviewKey: reviewKey(for: kanaCard))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    func kanaPreviewCardContent(for kanaCard: KanaStudyCard) -> some View {
        kanaCardBackContent(for: kanaCard)
            .padding(18)
            .appSurfaceCard()
    }

    func kanaCardBackContent(for kanaCard: KanaStudyCard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 18) {
                Text(kanaCard.character)
                    .font(.system(size: 82, weight: .regular, design: .serif))
                    .foregroundStyle(AppPalette.text)
                    .frame(width: 112, height: 112)
                    .background(AppPalette.surface)
                    .border(AppPalette.border.opacity(0.65))

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

            learningStatusLabel(forReviewKey: reviewKey(for: kanaCard))
        }
    }

}
