import Foundation
import Observation

@MainActor
@Observable
final class StudyPreferences {
    private static let hiddenKanjiDeckIDsKey = "hiddenKanjiDeckIDs"
    private struct StoredOptions: Codable {
        var version = 1
        var defaults: DeckOptions
        var decks: [String: DeckOptions]
    }
    private let defaults: UserDefaults
    private let errors: StorageStatus
    private var stored: StoredOptions
    private var canSave = true
    private(set) var hiddenKanjiDeckIDs: Set<String>

    init(defaults: UserDefaults = .standard, errors: StorageStatus) {
        self.defaults = defaults
        self.errors = errors
        stored = StoredOptions(defaults: DeckOptions(), decks: [:])
        hiddenKanjiDeckIDs = Set(defaults.stringArray(forKey: Self.hiddenKanjiDeckIDsKey) ?? [])
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

    func hideKanjiDeck(_ deck: KanjiDeck) {
        hiddenKanjiDeckIDs.insert(deck.id)
        defaults.set(hiddenKanjiDeckIDs.sorted(), forKey: Self.hiddenKanjiDeckIDsKey)
    }
}
