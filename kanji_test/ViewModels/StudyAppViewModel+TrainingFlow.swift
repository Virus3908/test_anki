import Foundation

extension StudyAppViewModel {
    func synchronizeTrainingRoute() {
        if case .training = navigation.route, !trainingSession.isActive {
            navigation.finishTraining()
            coordinator.resetPreviewSelection()
        }
    }
}
