import SwiftUI

extension CardContentRendering {
    func studyCardBackShell<Content: View>(
        reviewKey: String,
        isTextSelectable: Bool = true,
        onShowAllFields: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let onShowAllFields {
                HStack {
                    Text("Ответ")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                    Spacer()
                    Button("Все поля", systemImage: "list.bullet.rectangle", action: onShowAllFields)
                        .font(.caption)
                }
                .foregroundStyle(AppPalette.secondaryText)
            }

            content()
            learningStatusLabel(forReviewKey: reviewKey)
        }
        .modifier(TextSelectionModeModifier(isEnabled: isTextSelectable))
    }

    func largeCharacterPanel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 82, weight: .regular, design: .serif))
            .foregroundStyle(AppPalette.text)
            .frame(width: 112, height: 112)
            .background(AppPalette.surface)
            .border(AppPalette.border.opacity(0.65))
    }

    func learningStatusLabel(forReviewKey key: String) -> some View {
        Text(learningStatusText(forReviewKey: key))
            .font(.caption)
            .foregroundStyle(AppPalette.mutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func learningStatusText(forReviewKey key: String) -> String {
        StudyProgressStatus(
            record: reviewStore.record(for: key),
            isExcluded: reviewStore.isExcluded(key)
        ).title
    }
}

struct TextSelectionModeModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.textSelection(.enabled)
        } else {
            content.textSelection(.disabled)
        }
    }
}
