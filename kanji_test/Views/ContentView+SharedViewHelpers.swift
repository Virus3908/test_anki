import SwiftUI

extension ContentView {
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

    func previewStartButton(count: Int, isDisabled: Bool, action: @escaping () -> Void) -> some View {
        primaryActionButton(title: "Начать тренировку", systemImage: "shuffle", action: action) {
            HStack {
                Image(systemName: "shuffle")
                Text("Начать тренировку")
                    .fontWeight(.semibold)
                Spacer()
                Text("\(count)")
                    .fontWeight(.semibold)
            }
        }
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
