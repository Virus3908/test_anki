import Foundation
import Observation

enum StudyRoute: Equatable {
    case start
    case kanjiDeck(KanjiDeck)
    case wordDeck(WordFrequencyDeck)
    case kanaDeck(KanaDeck)
    case ankiDeck(AnkiDeckReference)
    case training(PracticeMode)
    case customTraining
}

@MainActor
@Observable
final class StudyNavigation {
    private(set) var route: StudyRoute = .start
    private var returnRoute: StudyRoute = .start

    var deckRoute: StudyRoute {
        switch route {
        case .training, .customTraining: return returnRoute
        default: return route
        }
    }

    func beginTraining(_ mode: PracticeMode) {
        if case .training = route {} else { returnRoute = route }
        route = .training(mode)
    }

    /// Starts the endless session for the currently open deck.
    /// The deck route is kept in `returnRoute` so preview state keeps resolving.
    func beginCustomTraining() {
        guard route.deck != nil else { return }
        if case .customTraining = route {} else { returnRoute = route }
        route = .customTraining
    }

    /// Exits the endless session back to the open deck preview.
    func finishCustomTraining() { route = returnRoute }

    func open(_ route: StudyRoute) { self.route = route }

    func finishTraining() { route = returnRoute }
    func reset() {
        route = .start
        returnRoute = .start
    }
}
