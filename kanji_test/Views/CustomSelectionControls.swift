import SwiftUI

/// Bottom start bar shown while a deck preview is in card selection mode.
/// Pinned edge-to-edge below the card grid; mass-selection lives in the header.
@MainActor
struct CustomSelectionBar: View, StudyViewStyling {
    let session: CustomTrainingSession
    let onStart: () -> Void

    private var selection: Set<String> { session.selectedIDs }

    var body: some View {
        primaryActionButton(
            title: selection.isEmpty
                ? "Выбери карточки"
                : "Начать · \(selection.count) \(customSelectionPluralCards(selection.count))",
            systemImage: selection.isEmpty ? "hand.tap" : "play.fill",
            action: onStart
        )
        .disabled(selection.isEmpty)
        .opacity(selection.isEmpty ? 0.55 : 1)
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial, ignoresSafeAreaEdges: .bottom)
    }
}

/// Mass-selection buttons shown as a row under the deck preview header
/// while cards are being picked, so the header row never gets crowded.
@MainActor
struct CustomSelectionToolbar: View, StudyViewStyling {
    let session: CustomTrainingSession
    /// IDs of all cards shown by the open deck preview.
    let cardIDs: [String]

    var body: some View {
        HStack(spacing: 8) {
            Button {
                session.setSelection(Set(cardIDs))
            } label: {
                Image(systemName: "checkmark.circle")
            }
            .accessibilityLabel("Выбрать все")

            Button {
                session.setSelection([])
            } label: {
                Image(systemName: "slash.circle")
            }
            .accessibilityLabel("Сбросить выбор")
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.accent)
    }
}

/// Marks a deck preview tile as part of the card selection:
/// picked tiles get an accent wash, stroke and checkmark badge.
/// Inactive (normal preview mode) it changes nothing.
struct CustomSelectionChrome: ViewModifier {
    let isSelecting: Bool
    let isSelected: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if isSelecting, isSelected {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppPalette.accent.opacity(0.12))
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppPalette.accent, lineWidth: 2)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body.weight(.bold))
                        .foregroundStyle(AppPalette.accent)
                        .padding(6)
                }
                .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    func customSelectionChrome(isSelecting: Bool, isSelected: Bool) -> some View {
        modifier(CustomSelectionChrome(isSelecting: isSelecting, isSelected: isSelected))
    }
}

func customSelectionPluralCards(_ count: Int) -> String {
    let mod10 = count % 10
    let mod100 = count % 100
    if mod10 == 1 && mod100 != 11 { return "карточка" }
    if mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14) { return "карточки" }
    return "карточек"
}
