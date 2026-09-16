import SwiftUI

struct TranslationRetryControls: View {
    let originalText: String
    let isLoading: Bool
    let action: () -> Void

    @State private var isOriginalPresented = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: action) {
                Label(
                    isLoading ? "Перевожу" : "Перевести заново",
                    systemImage: isLoading ? "hourglass" : "arrow.clockwise"
                )
            }
            .disabled(isLoading)

            Button {
                isOriginalPresented = true
            } label: {
                Image(systemName: "info.circle")
            }
            .accessibilityLabel("Показать оригинал")
            .popover(isPresented: $isOriginalPresented, arrowEdge: .bottom) {
                ScrollView {
                    Text(originalText.isEmpty ? "Оригинал пустой" : originalText)
                        .font(.footnote)
                        .foregroundStyle(AppPalette.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .padding(14)
                        .frame(width: 320, alignment: .leading)
                }
                .background(AppPalette.surface)
                .presentationCompactAdaptation(.popover)
            }
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
        .tint(AppPalette.accent)
    }
}
