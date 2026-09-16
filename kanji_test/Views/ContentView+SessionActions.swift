import SwiftUI

extension ContentView {
    func clearDeckCache() {
        KanjiDataLoader.clearCache()
        KanaDataLoader.clearCache()
        coordinator.resetAfterDeckCacheClear(deckState: deckState, trainingSession: trainingSession)
    }
}
