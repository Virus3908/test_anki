import SwiftUI

extension ContentView {
    func cardSwipeGesture() -> some Gesture {
        DragGesture(minimumDistance: 35)
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height
                guard abs(width) > abs(height) * 1.4, abs(width) > 70 else {
                    return
                }

                if width < 0 {
                    moveToNextCard()
                } else {
                    moveToPreviousCard()
                }
            }
    }

    func headerControls() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button("", systemImage: "square.grid.2x2") {
                    hasStartedTraining = false
                }

                Text(trainingTitle)
                    .font(.headline)

                Spacer()

                Text("Закреплено \(sessionCompletedCards) / \(sessionTotalCards)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .frame(minWidth: 128, alignment: .trailing)
            }

            let markers = sessionCardMarkers
            if !markers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(markers) { marker in
                            sessionCardMarker(marker)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.accent)
    }

    var sessionCardMarkers: [SessionCardMarker] {
        switch practiceMode {
        case .kanji:
            return uniqueMarkers(
                from: cards,
                key: \.kanji,
                title: \.kanji,
                masteredKeys: masteredKanjiKeys
            )
        case .words:
            return uniqueMarkers(
                from: wordCards,
                key: \.id,
                title: \.word,
                masteredKeys: masteredWordKeys
            )
        case .kana:
            return uniqueMarkers(
                from: kanaCards,
                key: \.character,
                title: \.character,
                masteredKeys: masteredKanaKeys
            )
        }
    }

    func uniqueMarkers<Item>(
        from items: [Item],
        key: KeyPath<Item, String>,
        title: KeyPath<Item, String>,
        masteredKeys: Set<String>
    ) -> [SessionCardMarker] {
        var seen: Set<String> = []
        return items.compactMap { item in
            let itemKey = item[keyPath: key]
            guard seen.insert(itemKey).inserted else {
                return nil
            }

            return SessionCardMarker(
                id: itemKey,
                title: item[keyPath: title],
                isMastered: masteredKeys.contains(itemKey)
            )
        }
    }

    func sessionCardMarker(_ marker: SessionCardMarker) -> some View {
        Text(marker.title)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(marker.isMastered ? Color.white : AppPalette.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(marker.isMastered ? AppPalette.success : AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(marker.isMastered ? AppPalette.success : AppPalette.border.opacity(0.55), lineWidth: 1)
            )
    }

}
