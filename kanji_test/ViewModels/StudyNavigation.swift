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
    var route: StudyRoute = .start
    private var returnRoute: StudyRoute = .start

    func beginTraining(_ mode: PracticeMode) {
        if case .training = route {} else { returnRoute = route }
        route = .training(mode)
    }

    func finishTraining() { route = returnRoute }
    func reset() {
        route = .start
        returnRoute = .start
    }
}
