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

    /// Уровень экрана в иерархии: главный — 0, колода — 1, тренировка — 2.
    /// Убывание уровня означает «назад» и задаёт направление анимации перехода.
    var navigationDepth: Int {
        switch self {
        case .start: 0
        case .kanjiDeck, .wordDeck, .kanaDeck, .ankiDeck: 1
        case .training, .customTraining: 2
        }
    }
}

@MainActor
@Observable
final class StudyNavigation {
    private(set) var route: StudyRoute = .start
    /// Последняя смена маршрута была «назад» (к менее глубокому экрану) —
    /// тогда страница уезжает вправо, как системный pop.
    private(set) var isMovingBack = false
    private var returnRoute: StudyRoute = .start

    var deckRoute: StudyRoute {
        switch route {
        case .training, .customTraining: return returnRoute
        default: return route
        }
    }

    func beginTraining(_ mode: PracticeMode) {
        if case .training = route {} else { returnRoute = route }
        moveTo(.training(mode))
    }

    /// Starts the endless session for the currently open deck.
    /// The deck route is kept in `returnRoute` so preview state keeps resolving.
    func beginCustomTraining() {
        guard route.deck != nil else { return }
        if case .customTraining = route {} else { returnRoute = route }
        moveTo(.customTraining)
    }

    /// Exits the endless session back to the open deck preview.
    func finishCustomTraining() { moveTo(returnRoute) }

    func open(_ route: StudyRoute) { moveTo(route) }

    func finishTraining() { moveTo(returnRoute) }
    func reset() {
        moveTo(.start)
        returnRoute = .start
    }

    private func moveTo(_ newRoute: StudyRoute) {
        isMovingBack = newRoute.navigationDepth < route.navigationDepth
        route = newRoute
    }
}
