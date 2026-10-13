import SwiftUI

struct TranslationRetryControls: View {
    let originalText: String
    let isLoading: Bool
    let action: () -> Void
    var showsRetryAction = true
    var accessibilityIdentifier: String?

    @State private var isOriginalPresented = false

    var body: some View {
        HStack(spacing: 8) {
            if showsRetryAction {
                Button(action: action) {
                    Label(
                        isLoading ? "Перевожу" : "Перевести заново",
                        systemImage: isLoading ? "hourglass" : "arrow.clockwise"
                    )
                }
                .disabled(isLoading)
                .accessibilityIdentifier(accessibilityIdentifier ?? "translation.retry")
            }

            Button {
                isOriginalPresented = true
            } label: {
                Image(systemName: "info.circle")
            }
            .accessibilityLabel("Показать оригинал")
            .accessibilityIdentifier(accessibilityIdentifier.map { "\($0).original" } ?? "translation.original")
            .popover(isPresented: $isOriginalPresented, arrowEdge: .bottom) {
                ScrollView {
                    Text(originalText.isEmpty ? "Оригинал пустой" : originalText)
                        .font(.footnote)
                        .foregroundStyle(AppPalette.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .padding(14)
                        .frame(maxWidth: 300, alignment: .leading)
                }
                .frame(maxHeight: 360)
                .background(AppPalette.surface)
                .presentationCompactAdaptation(.popover)
            }
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
        .tint(AppPalette.accent)
    }
}
