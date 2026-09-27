import Foundation

/// A user-visible step whose latency is part of the app's contract.
enum UserStep: String, CaseIterable {
    case launch
    case openDeck
    case openAnki
    case switchSection
    case openSearch
    case searchResults
    case openSearchResult
    case startTraining
    case revealCard
    case rateCard
    case drawStroke
    case speak
    case openCustomSelection
    case selectCard
    case startCustomTraining
    case exitTraining
    case backToStart
    case importAnki
    case relaunch

    /// Stage 1: generous; stage 2 tighten to user-perceived latency.
    var budget: TimeInterval {
        switch self {
        case .launch, .importAnki, .relaunch: 60
        default: 30
        }
    }
}
