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

/// Подсветка плитки по тому, как карточка знается в основном обучении колоды:
/// уверенно освоенные слегка притушены, нетронутые чуть подкрашены синим,
/// проблемные заливаются красным с ростом проблем, худшие дополнительно
/// получают красную рамку. Чем хуже/лучше знается — тем сильнее выражен эффект.
struct CardMasteryChrome: ViewModifier {
    /// `nil` (вне режима выбора) — модификатор ничего не меняет.
    let mastery: CardMastery?

    func body(content: Content) -> some View {
        content
            .opacity(dimming)
            .overlay {
                ZStack {
                    if let tint {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(tint)
                    }
                    if let problemStroke {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(problemStroke, lineWidth: 1.5)
                    }
                }
                .allowsHitTesting(false)
            }
    }

    private var dimming: Double {
        guard case .score(let score) = mastery, score >= Self.knownFloor else {
            return mastery == .excluded ? 0.6 : 1
        }
        return 1 - 0.45 * (score - Self.knownFloor) / (1 - Self.knownFloor)
    }

    private var tint: Color? {
        switch mastery {
        case .untrained:
            return AppPalette.newCard.opacity(0.09)
        case .score(let score) where score < Self.problemCeiling:
            let trouble = (Self.problemCeiling - score) / Self.problemCeiling
            return AppPalette.correction.opacity(0.05 + 0.17 * trouble)
        default:
            return nil
        }
    }

    private var problemStroke: Color? {
        guard case .score(let score) = mastery, score < Self.worstCeiling else { return nil }
        return AppPalette.correction.opacity(0.85)
    }

    /// Пороги полос: выше `knownFloor` — «уверенно знаю» (притушиваем),
    /// ниже `problemCeiling` — «проблемная» (подсвечиваем), ниже
    /// `worstCeiling` — худшие (рамка). Между порогами — нейтрально.
    private static let knownFloor = 0.55
    private static let problemCeiling = 0.4
    private static let worstCeiling = 0.15
}

extension View {
    func cardMasteryChrome(_ mastery: CardMastery?) -> some View {
        modifier(CardMasteryChrome(mastery: mastery))
    }
}

func customSelectionPluralCards(_ count: Int) -> String {
    let mod10 = count % 10
    let mod100 = count % 100
    if mod10 == 1 && mod100 != 11 { return "карточка" }
    if mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14) { return "карточки" }
    return "карточек"
}
