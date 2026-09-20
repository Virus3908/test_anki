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
    let kanjiProvider: any KanjiProviding
    var loadingRelatedWords: Set<String> = []
    var loadedRelatedWords: Set<String> = []
    var relatedWordLoadErrors: Set<String> = []
    var loadingAllRelatedWords: Set<String> = []
    var loadedAllRelatedWords: Set<String> = []
    var allRelatedWordLoadErrors: Set<String> = []
    var allRelatedWordIDsByKanji: [String: [String]] = [:]

    init(
        catalog: StudyCardCatalog,
        navigation: StudyNavigation,
        kanjiProvider: any KanjiProviding = KanjiAPIProvider()
    ) {
        self.catalog = catalog
        self.navigation = navigation
        self.kanjiProvider = kanjiProvider
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
    private var selectedLinkedWordCardID: String?
    var selectedLinkedWordCard: WordStudyCard? {
        get { selectedLinkedWordCardID.flatMap { catalog.word($0) } }
        set {
            if let newValue { catalog.register([newValue]) }
            selectedLinkedWordCardID = newValue?.id
        }
    }
    private var selectedLinkedWordKanjiCardID: String?
    var selectedLinkedWordKanjiCard: KanjiCard? {
        get { selectedLinkedWordKanjiCardID.flatMap { catalog.kanji($0) } }
        set {
            if let newValue { catalog.register([newValue]) }
            selectedLinkedWordKanjiCardID = newValue?.id
        }
    }
    private var selectedRelatedWordsKanjiCardID: String?
    var selectedRelatedWordsKanjiCard: KanjiCard? {
        get { selectedRelatedWordsKanjiCardID.flatMap { catalog.kanji($0) } }
        set {
            if let newValue { catalog.register([newValue]) }
            selectedRelatedWordsKanjiCardID = newValue?.id
        }
    }
    private var selectedRelatedWordsListWordCardID: String?
    var selectedRelatedWordsListWordCard: WordStudyCard? {
        get { selectedRelatedWordsListWordCardID.flatMap { catalog.word($0) } }
        set {
            if let newValue { catalog.register([newValue]) }
            selectedRelatedWordsListWordCardID = newValue?.id
        }
    }
    var presentedKanjiPreview: PresentedKanjiPreview?
    var presentedKanaPreview: PresentedKanaPreview?
    var presentedWordPreview: PresentedWordPreview?
    var previewSwipeDirection = 0
    var isDeckSchedulePresented = false
}
