import SwiftUI

extension ContentView {
    func trainingCardShell<Front: View, Back: View>(
        @ViewBuilder front: () -> Front,
        @ViewBuilder back: () -> Back
    ) -> some View {
        ZStack {
            front()
                .opacity(drawingSession.isAnswerVisible ? 0 : 1)
                .rotation3DEffect(.degrees(drawingSession.isAnswerVisible ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            ScrollView {
                back()
            }
            .opacity(drawingSession.isAnswerVisible ? 1 : 0)
            .rotation3DEffect(.degrees(drawingSession.isAnswerVisible ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .appSurfaceCard()
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .gesture(cardSwipeGesture())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.24)) {
                drawingSession.isAnswerVisible.toggle()
            }
        }
    }

    func studyCardFrontShell<Fields: View>(
        fallbackPrompt: String,
        footerText: String,
        reviewKey: String,
        isTextSelectable: Bool = true,
        @ViewBuilder fields: () -> Fields
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Задание")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.secondaryText)
                .textCase(.uppercase)

            fields()

            if !showsPromptCharacters && !showsPromptReading && !showsPromptMeaning {
                Text(fallbackPrompt)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppPalette.text)
            }

            Spacer(minLength: 16)

            Text(footerText)
                .foregroundStyle(AppPalette.secondaryText)

            learningStatusLabel(forReviewKey: reviewKey)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(TextSelectionModeModifier(isEnabled: isTextSelectable))
    }

    func studyCardBackShell<Content: View>(
        reviewKey: String,
        isTextSelectable: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
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
        StudyProgressStatus(record: reviewStore.record(for: key)).title
    }
}

private struct TextSelectionModeModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.textSelection(.enabled)
        } else {
            content.textSelection(.disabled)
        }
    }
}
