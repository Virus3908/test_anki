import SwiftUI

extension DeckPreviewView {
    func deckScheduleInfoView(for deck: KanjiDeck) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(deck.title)
                        .font(.title2.weight(.bold))

                    VStack(spacing: 8) {
                        ForEach(reviewStore.scheduleBuckets(for: deckState.previewCards)) { bucket in
                            HStack {
                                Text(bucket.title)
                                    .foregroundStyle(AppPalette.text)

                                Spacer()

                                Text("\(bucket.count)")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AppPalette.text)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppPalette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppPalette.border.opacity(0.55), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(20)
            }
            .background(AppPalette.background)
            .foregroundStyle(AppPalette.text)
            .navigationTitle("Повторения")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        coordinator.closeDeckSchedule()
                    }
                }
            }
        }
    }
}
