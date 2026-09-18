import Foundation
import Observation

struct PresentedKanjiPreview: Identifiable {
    let cardID: String
    var id: String { "kanji-preview" }
}

struct PresentedKanaPreview: Identifiable {
    let cardID: String
    var id: String { "kana-preview" }
}

struct PresentedWordPreview: Identifiable {
    let cardID: String
    var id: String { "word-preview" }
}

@MainActor
@Observable
final class StudyCoordinator {
    let catalog: StudyCardCatalog
    let navigation: StudyNavigation

    init(catalog: StudyCardCatalog, navigation: StudyNavigation) {
        self.catalog = catalog
        self.navigation = navigation
    }

    var hasStartedTraining: Bool {
        if case .training = navigation.route { return true }
        return false
    }
    var selectedDeck: KanjiDeck {
        if case .kanjiDeck(let deck) = navigation.deckRoute { return deck }
        return .jlpt5
    }
    var selectedKanaDeck: KanaDeck {
        if case .kanaDeck(let deck) = navigation.deckRoute { return deck }
        return .hiragana
    }
    var selectedWordDeck: WordFrequencyDeck {
        if case .wordDeck(let deck) = navigation.deckRoute { return deck }
        return .top1000
    }
    var selectedPreviewCard: KanjiCard? {
        get { (presentedKanjiPreview?.cardID).flatMap { catalog.kanji($0) } }
        set {
            if let newValue { catalog.register([newValue]) }
            presentedKanjiPreview = newValue.map { PresentedKanjiPreview(cardID: $0.id) }
        }
    }
    var selectedKanaPreviewCard: KanaStudyCard? {
        get { (presentedKanaPreview?.cardID).flatMap { catalog.kana($0) } }
        set {
            if let newValue { catalog.register([newValue]) }
            presentedKanaPreview = newValue.map { PresentedKanaPreview(cardID: $0.id) }
        }
    }
    var selectedWordPreviewCard: WordStudyCard? {
        get { (presentedWordPreview?.cardID).flatMap { catalog.word($0) } }
        set {
            if let newValue { catalog.register([newValue]) }
            presentedWordPreview = newValue.map { PresentedWordPreview(cardID: $0.id) }
        }
    }
    private var selectedLinkedKanjiCardID: String?
    var selectedLinkedKanjiCard: KanjiCard? {
        get { selectedLinkedKanjiCardID.flatMap { catalog.kanji($0) } }
        set {
            if let newValue { catalog.register([newValue]) }
            selectedLinkedKanjiCardID = newValue?.id
        }
    }
    var presentedKanjiPreview: PresentedKanjiPreview?
    var presentedKanaPreview: PresentedKanaPreview?
    var presentedWordPreview: PresentedWordPreview?
    var previewSwipeDirection = 0
    var isDeckSchedulePresented = false
}
