import Foundation
import Observation

enum StudyRoute: Equatable {
    case start
    case kanjiDeck(KanjiDeck)
    case wordDeck(WordFrequencyDeck)
    case kanaDeck(KanaDeck)
    case ankiDeck(AnkiDeckReference)
    case training(PracticeMode)
}

@MainActor
@Observable
final class StudyNavigation {
    private(set) var route: StudyRoute = .start
    private var returnRoute: StudyRoute = .start

    var deckRoute: StudyRoute {
        if case .training = route { return returnRoute }
        return route
    }

    func beginTraining(_ mode: PracticeMode) {
        if case .training = route {} else { returnRoute = route }
        route = .training(mode)
    }

    func open(_ route: StudyRoute) { self.route = route }

    func finishTraining() { route = returnRoute }
    func reset() {
        route = .start
        returnRoute = .start
    }
}
