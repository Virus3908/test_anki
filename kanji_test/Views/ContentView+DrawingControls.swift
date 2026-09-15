import SwiftUI

extension ContentView {
    func reviewButton(_ title: String, rating: ReviewRating, card: KanjiCard, color: Color) -> some View {
        ratingActionButton(title, color: color) {
            applyReview(rating, to: card)
        }
        .disabled(isPreparingCard)
    }

    func ratingActionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.white)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }

    func feedbackInfoButton(items: [StrokeFeedback]) -> some View {
        Button {
            showsFeedbackInfo = true
        } label: {
            Image(systemName: "info.circle")
        }
        .popover(isPresented: $showsFeedbackInfo, arrowEdge: .bottom) {
            feedbackInfoPopover(items: items)
                .presentationCompactAdaptation(.popover)
        }
    }

    func feedbackInfoPopover(items: [StrokeFeedback]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Проверка")
                .font(.headline)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items) { item in
                        Text(item.message)
                            .font(.footnote)
                            .foregroundStyle(item.severity.textColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxHeight: 260)
        }
        .padding(14)
        .frame(width: 300, alignment: .leading)
        .background(AppPalette.surface)
    }

    func drawingPanelHeight(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.36, 250), 300)
    }

    func drawingBoardSide(for panelHeight: CGFloat) -> CGFloat {
        min(max(panelHeight - 88, 160), 205)
    }

}
