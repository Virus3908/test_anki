import SwiftUI

extension SettingsView {
    func frontSettingsView() -> some View {
        settingsSection("Лицевая сторона") {
            VStack(spacing: 8) {
                ForEach(options.frontFieldOrder) { field in
                    if field != .meanings || StudyDeck.builtIn.first(where: { $0.id == selectedDeckID })?.mode != .kana {
                        frontSettingRow(for: field)
                    }
                }
            }
        }
    }

    func frontSettingRow(for field: FrontFieldKind) -> some View {
        HStack(spacing: 10) {
            Toggle(field.title, isOn: binding(for: field))

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Button {
                    moveFrontField(field, direction: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(width: 28, height: 28)
                }
                .disabled(!canMoveFrontField(field, direction: -1))
                .accessibilityLabel("Переместить выше")

                Button {
                    moveFrontField(field, direction: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: 28, height: 28)
                }
                .disabled(!canMoveFrontField(field, direction: 1))
                .accessibilityLabel("Переместить ниже")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(AppPalette.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppPalette.background.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.28, dampingFraction: 0.95), value: options.frontFieldOrder)
    }

    func canMoveFrontField(_ field: FrontFieldKind, direction: Int) -> Bool {
        guard let currentIndex = options.frontFieldOrder.firstIndex(of: field) else {
            return false
        }

        return options.frontFieldOrder.indices.contains(currentIndex + direction)
    }

    func moveFrontField(_ field: FrontFieldKind, direction: Int) {
        guard let currentIndex = options.frontFieldOrder.firstIndex(of: field) else {
            return
        }

        let targetIndex = currentIndex + direction
        guard options.frontFieldOrder.indices.contains(targetIndex) else {
            return
        }

        withAnimation(.easeOut(duration: 0.16)) {
            settings.updateOptions(for: deckID) {
                $0.frontFieldOrder.move(fromOffsets: IndexSet(integer: currentIndex),
                    toOffset: targetIndex > currentIndex ? targetIndex + 1 : targetIndex)
            }
        }
    }

    func binding(for field: FrontFieldKind) -> Binding<Bool> {
        switch field {
        case .readings: return optionBinding(\.showsPromptReading)
        case .meanings: return optionBinding(\.showsPromptMeaning)
        case .character: return optionBinding(\.showsPromptCharacters)
        }
    }
}
