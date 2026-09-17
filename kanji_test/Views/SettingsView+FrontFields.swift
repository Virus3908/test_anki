import SwiftUI

extension SettingsView {
    func frontSettingsView() -> some View {
        settingsSection("Лицевая сторона") {
            VStack(spacing: 8) {
                ForEach(settings.frontFieldOrder) { field in
                    frontSettingRow(for: field)
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
        .animation(.spring(response: 0.28, dampingFraction: 0.95), value: settings.frontFieldOrder)
    }

    func canMoveFrontField(_ field: FrontFieldKind, direction: Int) -> Bool {
        guard let currentIndex = settings.frontFieldOrder.firstIndex(of: field) else {
            return false
        }

        return settings.frontFieldOrder.indices.contains(currentIndex + direction)
    }

    func moveFrontField(_ field: FrontFieldKind, direction: Int) {
        guard let currentIndex = settings.frontFieldOrder.firstIndex(of: field) else {
            return
        }

        let targetIndex = currentIndex + direction
        guard settings.frontFieldOrder.indices.contains(targetIndex) else {
            return
        }

        withAnimation(.easeOut(duration: 0.16)) {
            settings.frontFieldOrder.move(
                fromOffsets: IndexSet(integer: currentIndex),
                toOffset: targetIndex > currentIndex ? targetIndex + 1 : targetIndex
            )
        }
    }

    func binding(for field: FrontFieldKind) -> Binding<Bool> {
        switch field {
        case .readings:
            return Binding(
                get: { settings.showsPromptReading },
                set: { settings.showsPromptReading = $0 }
            )
        case .meanings:
            return Binding(
                get: { settings.showsPromptMeaning },
                set: { settings.showsPromptMeaning = $0 }
            )
        case .character:
            return Binding(
                get: { settings.showsPromptCharacters },
                set: { settings.showsPromptCharacters = $0 }
            )
        }
    }
}
