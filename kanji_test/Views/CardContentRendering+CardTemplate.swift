import SwiftUI

extension CardContentRendering {
    func studyCardBackShell<Content: View>(
        reviewKey: String,
        isTextSelectable: Bool = true,
        onShowAllFields: (() -> Void)? = nil,
        onSpeak: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let onShowAllFields {
                HStack {
                    Text("Ответ")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                    Spacer()
                    if let onSpeak {
                        CardHeaderActionButton(
                            title: "Озвучить",
                            systemImage: "speaker.wave.2.fill",
                            action: onSpeak
                        )
                    }
                    CardHeaderActionButton(
                        title: "Все поля",
                        systemImage: "list.bullet.rectangle",
                        action: onShowAllFields
                    )
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

struct BuiltInCardPreviewActions: View {
    let speechText: String
    let settings: StudyPreferences
    let deckID: String?
    let mode: PracticeMode

    @State private var speech = SpeechService()
    @State private var isFieldSettingsPresented = false

    var body: some View {
        HStack {
            Spacer()

            CardHeaderActionButton(
                title: "Озвучить",
                systemImage: "speaker.wave.2.fill"
            ) {
                speech.voiceIdentifier = settings.speechVoiceIdentifier.isEmpty
                    ? nil
                    : settings.speechVoiceIdentifier
                speech.rate = settings.speechRate
                speech.speak(speechText)
            }

            CardHeaderActionButton(
                title: "Все поля",
                systemImage: "list.bullet.rectangle"
            ) {
                isFieldSettingsPresented = true
            }
        }
        .foregroundStyle(AppPalette.secondaryText)
        .sheet(isPresented: $isFieldSettingsPresented) {
            BuiltInCardFieldSettingsView(
                settings: settings,
                deckID: deckID,
                mode: mode,
                initialSide: .back
            )
        }
        .onDisappear { speech.stop() }
    }
}

struct CardHeaderActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(CardHeaderActionButtonStyle())
    }
}

private struct CardHeaderActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundStyle(AppPalette.secondaryText.opacity(0.75))
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
