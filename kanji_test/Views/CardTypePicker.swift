import SwiftUI

/// Multi-select chips for the card types available to one deck. Keeps at least
/// one type selected and reports the whole selection through `onChange`.
struct CardTypePicker: View {
    let available: [TrainingCardType]
    let selection: Set<TrainingCardType>
    let onChange: (Set<TrainingCardType>) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
            ForEach(available) { type in
                typeChip(type)
            }
        }
    }

    private func typeChip(_ type: TrainingCardType) -> some View {
        let isSelected = selection.contains(type)
        return Button {
            toggle(type)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: type.symbolName)
                Text(type.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(isSelected ? AppPalette.accent.opacity(0.18) : AppPalette.surface)
            .foregroundStyle(isSelected ? AppPalette.accent : AppPalette.text)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? AppPalette.accent : AppPalette.border, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func toggle(_ type: TrainingCardType) {
        if selection.contains(type) {
            guard selection.count > 1 else { return }
            onChange(selection.subtracting([type]))
        } else {
            onChange(selection.union([type]))
        }
    }
}
