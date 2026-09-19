import Foundation
import Observation
import AnkiImport

@MainActor @Observable
final class AnkiLibraryViewModel {
    private let repository: any AnkiLibraryPersisting
    var imports: [AnkiImportSummary] = []
    var isImporting = false
    var isLoaded = false
    var message: String?
    var canRestoreBackup = false
    private(set) var previewCards: [AnkiStudyCard] = []
    private(set) var previewDeck: AnkiDeckReference?
    private(set) var isOpeningDeck = false
    var loadError: String?
    private let request = LoadRequest()
    private var openToken: UUID { request.id }
    private var isLoading = false
    @ObservationIgnored var bootstrapScheduling: ((AnkiCollection, String) async throws -> Int)?

    init(repository: any AnkiLibraryPersisting = AnkiRepository()) {
        self.repository = repository
    }

    var decks: [AnkiDeckReference] {
        var result: [AnkiDeckReference] = []
        for item in imports {
            for deck in item.decks {
                let count = item.deckCardCounts?[String(deck.id)] ?? 0
                guard count > 0 else { continue }
                result.append(AnkiDeckReference(importID: item.id, sourceDeckID: deck.id, title: deck.name, cardCount: count))
            }
        }
        return result.sorted { $0.title == $1.title ? $0.id < $1.id : $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func load() async {
        guard !isLoaded, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            imports = try await repository.load()
            try await migratePendingScheduling()
            imports = try await repository.load()
            isLoaded = true
        }
        catch { message = error.localizedDescription; canRestoreBackup = await repository.hasRecoverableBackup() }
    }

    func restoreBackup() async {
        do { imports = try await repository.restoreBackup(); isLoaded = true; canRestoreBackup = false }
        catch { message = error.localizedDescription }
    }

    func importPackage(_ url: URL) async {
        guard !isImporting, isLoaded else { return }
        isImporting = true
        defer { isImporting = false }
        do {
            let result = try await repository.importPackage(url)
            let imported = try await migrateScheduling(result.summary)
            imports = try await repository.load()
            message = result.alreadyImported ? "Этот файл уже импортирован." :
                "Импортировано: \(result.summary.deckCardCounts?.count ?? 0) колод, \(result.summary.cardCount) карточек, \(result.summary.mediaCount) медиафайлов."
            if imported > 0 { message = (message ?? "") + "\nПеренесено расписание: \(imported) карточек." }
            if !result.summary.warnings.isEmpty { message = (message ?? "") + "\n\n" + result.summary.warnings.joined(separator: "\n") }
        } catch { message = error.localizedDescription }
    }

    private func migratePendingScheduling() async throws {
        for summary in imports where summary.schedulingMigrationVersion != AnkiSchedulingMigrator.version {
            _ = try await migrateScheduling(summary)
        }
    }

    private func migrateScheduling(_ summary: AnkiImportSummary) async throws -> Int {
        guard summary.schedulingMigrationVersion != AnkiSchedulingMigrator.version,
              let bootstrapScheduling else { return 0 }
        let collection = try await repository.collection(summary)
        let count = try await bootstrapScheduling(collection, summary.id)
        try await repository.markSchedulingMigration(importID: summary.id, version: AnkiSchedulingMigrator.version)
        return count
    }

    func open(_ summary: AnkiImportSummary) async throws -> (AnkiCollection, URL) {
        let collection = try await repository.collection(summary)
            let media = try await repository.mediaDirectory(summary)
        return (collection, media)
    }

    func openDeck(_ deck: AnkiDeckReference) async {
        request.cancel()
        await loadDeck(deck)
    }

    private func loadDeck(_ deck: AnkiDeckReference) async {
        let token = openToken
        previewDeck = deck
        previewCards = []
        loadError = nil
        isOpeningDeck = true
        defer { if openToken == token { isOpeningDeck = false } }
        do {
            guard let summary = imports.first(where: { $0.id == deck.importID }) else {
                throw AnkiImportError.invalid("колода отсутствует в библиотеке")
            }
            let (collection, media) = try await open(summary)
            let cards = await Task.detached(priority: .userInitiated) {
                let notes = Dictionary(uniqueKeysWithValues: collection.notes.map { ($0.id, $0) })
                let types = Dictionary(uniqueKeysWithValues: collection.noteTypes.map { ($0.id, $0) })
                return collection.cards.filter { $0.deckID == deck.sourceDeckID }.compactMap { card -> AnkiStudyCard? in
                    guard let note = notes[card.noteID], let type = types[note.noteTypeID] else { return nil }
                    return AnkiStudyCard(importID: deck.importID, card: card, note: note, noteType: type, deckName: deck.title, mediaDirectory: media)
                }
            }.value
            guard openToken == token, !Task.isCancelled else { return }
            previewCards = cards
        } catch { if openToken == token { loadError = error.localizedDescription } }
    }

    func closeDeck() {
        request.cancel()
        isOpeningDeck = false
        previewCards = []
        previewDeck = nil
        loadError = nil
    }

    func beginOpening(_ deck: AnkiDeckReference) {
        request.cancel()
        request.task = Task { [weak self] in await self?.loadDeck(deck) }
    }
}
