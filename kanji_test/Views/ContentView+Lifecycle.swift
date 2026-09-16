import SwiftUI

extension ContentView {
    func loadReviewMemory() async {
        await appModel.loadSavedState()
    }
}
