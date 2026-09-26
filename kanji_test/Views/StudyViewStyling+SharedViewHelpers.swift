import SwiftUI

extension StudyViewStyling {
    func surfaceCard<Content: View>(
        cornerRadius: CGFloat = 8,
        borderOpacity: Double = 0.65,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .appSurfaceCard(cornerRadius: cornerRadius, borderOpacity: borderOpacity)
    }

    func previewHeader<Actions: View>(
        title: String,
        subtitle: String,
        onBack: @escaping () -> Void,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(spacing: 12) {
            Button("", systemImage: "chevron.left", action: onBack)
                .buttonStyle(.bordered)
                .tint(AppPalette.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.weight(.bold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppPalette.secondaryText)
            }

            Spacer()
            actions()
        }
    }

    func previewHeader(title: String, subtitle: String, onBack: @escaping () -> Void) -> some View {
        previewHeader(title: title, subtitle: subtitle, onBack: onBack) {
            EmptyView()
        }
    }

    /// One capsule with two zones: the big left part starts normal training,
    /// the small right part opens the custom card picker.
    func previewStartButton(
        plan: StudyQueuePlan,
        isDisabled: Bool,
        action: @escaping () -> Void,
        onCustomTraining: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 0) {
            Button(action: action) {
                HStack {
                    Image(systemName: "shuffle")
                    Text("Начать тренировку")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(plan.newCount)/\(plan.learningCount)/\(plan.reviewCount)")
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "Начать тренировку. Новые: \(plan.newCount). "
                    + "Повторяемые: \(plan.learningCount). К просмотру: \(plan.reviewCount)"
            )

            Rectangle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 1, height: 30)

            Button(action: onCustomTraining) {
                Image(systemName: "checklist")
                    .font(.title3.weight(.semibold))
                    .frame(minWidth: 58, minHeight: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Кастом-тренировка: выбрать карточки")
        }
        .foregroundStyle(Color.white)
        .background(AppPalette.accent, in: Capsule())
        .opacity(isDisabled ? 0.5 : 1)
        .disabled(isDisabled)
    }

    func primaryActionButton<Label: View>(
        title: String,
        systemImage: String,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
                .foregroundStyle(Color.white)
                .padding(14)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppPalette.accent)
    }

    func primaryActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        primaryActionButton(title: title, systemImage: systemImage, action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
                    .fontWeight(.semibold)
            }
        }
    }

    func detailBlock<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.secondaryText)
            content()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func translatableTextBlock<Controls: View>(
        _ title: String,
        text: String,
        @ViewBuilder controls: () -> Controls
    ) -> some View {
        detailBlock(title) {
            VStack(alignment: .leading, spacing: 8) {
                Text(text)
                    .foregroundStyle(AppPalette.text)
                    .fixedSize(horizontal: false, vertical: true)

                controls()
            }
        }
    }

}

struct SurfaceCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let borderOpacity: Double

    func body(content: Content) -> some View {
        content
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: AppPalette.text.opacity(0.08), radius: 10, x: 0, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppPalette.border.opacity(borderOpacity), lineWidth: 1)
            )
    }
}

extension View {
    func appSurfaceCard(cornerRadius: CGFloat = 8, borderOpacity: Double = 0.65) -> some View {
        modifier(SurfaceCardModifier(cornerRadius: cornerRadius, borderOpacity: borderOpacity))
    }
}

struct BottomScrollMask: View {
    var body: some View {
        VStack(spacing: 0) {
            AppPalette.background
            LinearGradient(
                colors: [AppPalette.background, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 44)
        }
    }
}

struct CenteredLoadingIndicator: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(AppPalette.accent)
            Text(title)
                .foregroundStyle(AppPalette.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}
