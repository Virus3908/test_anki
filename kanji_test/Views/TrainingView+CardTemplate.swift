import SwiftUI

extension TrainingView {
    func trainingCardShell<Front: View, Back: View>(
        @ViewBuilder front: () -> Front,
        @ViewBuilder back: () -> Back
    ) -> some View {
        ZStack {
            ScrollView {
                front()
            }
            .scrollIndicators(.hidden)
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
        speechText: String? = nil,
        isTextSelectable: Bool = true,
        @ViewBuilder fields: () -> Fields
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Задание")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                Spacer()
                if let speechText, !speechText.isEmpty {
                    CardHeaderActionButton(title: "Озвучить", systemImage: "speaker.wave.2.fill") {
                        speech.speak(speechText)
                    }
                }
                CardHeaderActionButton(title: "Все поля", systemImage: "list.bullet.rectangle") {
                    presentCardFieldSettings(side: .front)
                }
            }
            .foregroundStyle(AppPalette.secondaryText)

            fields()

            if cardFields(for: practiceMode, side: .front).isEmpty {
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
        .sheet(isPresented: $isCardFieldSettingsPresented) {
            BuiltInCardFieldSettingsView(
                settings: settings,
                deckID: deckID,
                mode: practiceMode,
                initialSide: cardFieldSettingsSide
            )
        }
    }

    func presentCardFieldSettings(side: BuiltInCardSide) {
        cardFieldSettingsSide = side
        isCardFieldSettingsPresented = true
    }

}
