import Foundation

extension StudyAppViewModel {
    func loadSavedState() async {
        await Task.yield()
        coordinator.reviewStore = ReviewRepository.load()
        translationState.loadSavedTranslations()
    }
}
