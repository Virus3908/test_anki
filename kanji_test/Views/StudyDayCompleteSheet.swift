import SwiftUI

struct StudyDayCompleteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cardCount: Int
    let onAddCards: (Int) -> Void

    init(defaultCount: Int, onAddCards: @escaping (Int) -> Void) {
        _cardCount = State(initialValue: min(100, max(1, defaultCount)))
        self.onAddCards = onAddCards
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(AppPalette.success)

            Text("На сегодня всё")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppPalette.text)

            Text("Карточки, которым назначен следующий день, вернутся в очередь позже.")
                .font(.body)
                .foregroundStyle(AppPalette.secondaryText)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Text("Добавить карточек")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppPalette.text)

                TextField("Количество", value: cardCountBinding, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 72)
                    .padding(.vertical, 8)
                    .background(AppPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Stepper("", value: cardCountBinding, in: 1...100)
                    .labelsHidden()
            }
            .padding(.horizontal, 8)

            Button("Добавить и учиться") {
                onAddCards(cardCount)
                dismiss()
            }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.accent)
                .padding(.top, 6)

            Button("Остаться в колоде") { dismiss() }
                .buttonStyle(.bordered)
                .tint(AppPalette.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
        .background(AppPalette.background)
    }

    private var cardCountBinding: Binding<Int> {
        Binding(
            get: { cardCount },
            set: { cardCount = min(100, max(1, $0)) }
        )
    }
}
