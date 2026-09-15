import SwiftUI

extension ContentView {
    func kanaStudyCard(for kanaCard: KanaStudyCard) -> some View {
        ZStack {
            kanaCardFront(for: kanaCard)
                .opacity(isAnswerVisible ? 0 : 1)
                .rotation3DEffect(.degrees(isAnswerVisible ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            kanaCardBack(for: kanaCard)
                .opacity(isAnswerVisible ? 1 : 0)
                .rotation3DEffect(.degrees(isAnswerVisible ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppPalette.border.opacity(0.65), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .gesture(cardSwipeGesture())
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    func kanaPreviewCardContent(for kanaCard: KanaStudyCard) -> some View {
        kanaCardBackContent(for: kanaCard)
            .padding(18)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.border.opacity(0.65), lineWidth: 1)
            )
    }

    func kanaCardBack(for kanaCard: KanaStudyCard) -> some View {
        ScrollView {
            kanaCardBackContent(for: kanaCard)
        }
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
        }
    }

}
