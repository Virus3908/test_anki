import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class StudyPreferences {
    private static let hiddenKanjiDeckIDsKey = "hiddenKanjiDeckIDs"
    private static let speechEnabledKey = "speechEnabled"
    private static let speechVoiceIdentifierKey = "speechVoiceIdentifier"
    private static let speechRateKey = "speechRate"
    private struct StoredOptions: Codable {
        var version = 1
        var defaults: DeckOptions
        var decks: [String: DeckOptions]
    }
    private struct AdditionalCards: Codable {
        var version = 1
        var decks: [String: Grant] = [:]
        struct Grant: Codable { let studyDay: Date; var count: Int }
    }
    private var additionalCards = AdditionalCards()
    private var canSaveAdditionalCards = true

    private let defaults: UserDefaults
    private let errors: StorageStatus
    private var stored: StoredOptions
    private var canSave = true
    private(set) var hiddenKanjiDeckIDs: Set<String>
    var showExampleFurigana: Bool {
        didSet { defaults.set(showExampleFurigana, forKey: "showExampleFurigana") }
    }
    var speechEnabled: Bool {
        didSet { defaults.set(speechEnabled, forKey: Self.speechEnabledKey) }
    }
    var speechVoiceIdentifier: String {
        didSet { defaults.set(speechVoiceIdentifier, forKey: Self.speechVoiceIdentifierKey) }
    }
    var speechRate: Float {
        didSet { defaults.set(speechRate, forKey: Self.speechRateKey) }
    }

    init(defaults: UserDefaults = .standard, errors: StorageStatus) {
        self.defaults = defaults
        self.errors = errors
        stored = StoredOptions(defaults: DeckOptions(), decks: [:])
        hiddenKanjiDeckIDs = Set(defaults.stringArray(forKey: Self.hiddenKanjiDeckIDsKey) ?? [])
        showExampleFurigana = defaults.object(forKey: "showExampleFurigana") as? Bool ?? true
        speechEnabled = defaults.object(forKey: Self.speechEnabledKey) as? Bool ?? true
        speechVoiceIdentifier = defaults.string(forKey: Self.speechVoiceIdentifierKey) ?? ""
        speechRate = defaults.object(forKey: Self.speechRateKey) as? Float ?? AVSpeechUtteranceDefaultSpeechRate
        if let data = defaults.data(forKey: "additionalStudyCards") {
            do {
                let decoded = try JSONDecoder().decode(AdditionalCards.self, from: data)
                guard decoded.version == 1 else { throw StorageFormatError.unsupportedVersion(decoded.version) }
                additionalCards = decoded
            } catch {
                canSaveAdditionalCards = false
                errors.report("Не удалось прочитать дополнительные лимиты. Исходные данные сохранены.", error: error)
            }
        }
        if let data = defaults.data(forKey: "studyDeckOptions") {
            do {
                let decoded = try JSONDecoder().decode(StoredOptions.self, from: data)
                guard decoded.version == 1 else { throw StorageFormatError.unsupportedVersion(decoded.version) }
                stored = decoded
            } catch {
                canSave = false
                errors.report("Не удалось прочитать настройки колод. Исходные настройки сохранены.", error: error)
            }
        }
    }

    func options(for deckID: String?) -> DeckOptions {
        (deckID.flatMap { stored.decks[$0] } ?? stored.defaults).validated
    }

    func effectiveOptions(for deckID: String?, studyDay: Date, calendar: Calendar = .current) -> DeckOptions {
        var result = options(for: deckID)
        result.dailyNewCardLimit = min(9999, result.dailyNewCardLimit
            + additionalCardCount(for: deckID, studyDay: studyDay, calendar: calendar))
        return result
    }

    func updateOptions(for deckID: String?, _ change: (inout DeckOptions) -> Void) {
        guard canSave else {
            errors.message = "Настройки не сохранены: сначала восстанови читаемую версию настроек колод."
            return
        }
        var options = options(for: deckID)
        change(&options)
        var next = stored
        if let deckID { next.decks[deckID] = options.validated }
        else { next.defaults = options.validated }
        do {
            let data = try JSONEncoder().encode(next)
            defaults.set(data, forKey: "studyDeckOptions")
            stored = next
        } catch { errors.report("Не удалось сохранить настройки колоды.", error: error) }
    }

    func additionalCardCount(for deckID: String?, studyDay: Date, calendar: Calendar = .current) -> Int {
        guard let deckID, let grant = additionalCards.decks[deckID],
              calendar.isDate(grant.studyDay, inSameDayAs: studyDay) else { return 0 }
        return min(9999, max(0, grant.count))
    }

    func addAdditionalCards(_ count: Int, for deckID: String, studyDay: Date, calendar: Calendar = .current) {
        guard canSaveAdditionalCards else { return }
        var next = additionalCards
        next.decks = next.decks.filter { calendar.isDate($0.value.studyDay, inSameDayAs: studyDay) }
        let existing = additionalCardCount(for: deckID, studyDay: studyDay, calendar: calendar)
        next.decks[deckID] = .init(studyDay: studyDay, count: min(9999, existing + min(9999, max(1, count))))
        saveAdditionalCards(next)
    }

    func expireAdditionalCards(studyDay: Date, calendar: Calendar = .current) {
        guard canSaveAdditionalCards else { return }
        var next = additionalCards
        next.decks = next.decks.filter { calendar.isDate($0.value.studyDay, inSameDayAs: studyDay) }
        guard next.decks.count != additionalCards.decks.count else { return }
        saveAdditionalCards(next)
    }

    private func saveAdditionalCards(_ next: AdditionalCards) {
        do {
            defaults.set(try JSONEncoder().encode(next), forKey: "additionalStudyCards")
            additionalCards = next
        } catch { errors.report("Не удалось сохранить дополнительные лимиты.", error: error) }
    }

    func hideKanjiDeck(_ deck: KanjiDeck) {
        hiddenKanjiDeckIDs.insert(deck.id)
        defaults.set(hiddenKanjiDeckIDs.sorted(), forKey: Self.hiddenKanjiDeckIDsKey)
    }
}
