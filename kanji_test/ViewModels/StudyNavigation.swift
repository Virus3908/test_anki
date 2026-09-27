import Foundation
import Observation

enum StudyRoute: Hashable {
    case start
    case kanjiDeck(KanjiDeck)
    case wordDeck(WordFrequencyDeck)
    case kanaDeck(KanaDeck)
    case ankiDeck(AnkiDeckReference)
    case training(PracticeMode)
    case customTraining
}

/// Колоды живут в стеке `path` (системный push/pop со «стаскиванием»),
/// тренировки — в `presentedTraining` поверх стека, чтобы свайп-назад
/// не мог случайно прервать тренировку.
@MainActor
@Observable
final class StudyNavigation {
    var path: [StudyRoute] = []
    private(set) var presentedTraining: StudyRoute?

    var route: StudyRoute { presentedTraining ?? deckRoute }
    var deckRoute: StudyRoute { path.last ?? .start }

    func beginTraining(_ mode: PracticeMode) {
        presentedTraining = .training(mode)
    }

    /// Starts the endless session for the currently open deck.
    func beginCustomTraining() {
        guard deckRoute.deck != nil else { return }
        presentedTraining = .customTraining
    }

    func finishCustomTraining() { presentedTraining = nil }
    func finishTraining() { presentedTraining = nil }

    func open(_ route: StudyRoute) {
        presentedTraining = nil
        path = route == .start ? [] : [route]
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func reset() { open(.start) }
}
