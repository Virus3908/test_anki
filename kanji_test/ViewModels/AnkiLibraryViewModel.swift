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
    private(set) var isDeletingDeck = false
    var loadError: String?
    private let request = LoadRequest()
    private var openToken: UUID { request.id }
    private var isLoading = false
    /// `nil` means the bootstrap could not run yet (e.g. review progress is not loaded);
    /// the migration must then stay unmarked so it is retried later.
    @ObservationIgnored var bootstrapScheduling: ((AnkiCollection, String) async throws -> Int?)?

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
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        if !isLoaded {
            do { imports = try await repository.load() }
            catch {
                message = error.localizedDescription
                canRestoreBackup = await repository.hasRecoverableBackup()
                return
            }
            isLoaded = true
        }
        await runPendingSchedulingMigrations()
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

    func deleteDeck(_ deck: AnkiDeckReference) async -> Bool {
        guard !isDeletingDeck, !isImporting else { return false }
        isDeletingDeck = true
        defer { isDeletingDeck = false }
        do {
            try await repository.deleteImport(id: deck.importID)
            imports = try await repository.load()
            closeDeck()
            return true
        } catch {
            loadError = error.localizedDescription
            return false
        }
    }

    private func runPendingSchedulingMigrations() async {
        guard bootstrapScheduling != nil else { return }
        var failures: [String] = []
        for summary in imports where summary.schedulingMigrationVersion != AnkiSchedulingMigrator.version {
            do { _ = try await migrateScheduling(summary) }
            catch { failures.append("\(summary.filename): \(error.localizedDescription)") }
        }
        guard !failures.isEmpty else { return }
        message = "Не удалось перенести расписание:\n" + failures.joined(separator: "\n")
            + "\nКолоды доступны, перенос повторится при следующей загрузке."
    }

    private func migrateScheduling(_ summary: AnkiImportSummary) async throws -> Int {
        guard summary.schedulingMigrationVersion != AnkiSchedulingMigrator.version,
              let bootstrapScheduling else { return 0 }
        let collection = try await repository.collection(summary)
        guard let count = try await bootstrapScheduling(collection, summary.id) else { return 0 }
        try await repository.markSchedulingMigration(importID: summary.id, version: AnkiSchedulingMigrator.version)
        if let index = imports.firstIndex(where: { $0.id == summary.id }) {
            imports[index].schedulingMigrationVersion = AnkiSchedulingMigrator.version
        }
        return count
    }

    func open(_ summary: AnkiImportSummary) async throws -> (AnkiCollection, URL) {
        let collection = try await repository.collection(summary)
        let media = try await repository.mediaDirectory(summary)
        return (collection, media)
    }

    /// Загружает карточки всех импортов для глобального поиска, не меняя
    /// состояние открытой в интерфейсе колоды.
    func cardsForSearch() async throws -> [AnkiStudyCard] {
        if !isLoaded {
            await load()
        }

        var result: [AnkiStudyCard] = []
        for summary in imports {
            let (collection, media) = try await open(summary)
            let importCards = await Task.detached(priority: .userInitiated) {
                let notes = Dictionary(uniqueKeysWithValues: collection.notes.map { ($0.id, $0) })
                let types = Dictionary(uniqueKeysWithValues: collection.noteTypes.map { ($0.id, $0) })
                let deckNames = Dictionary(uniqueKeysWithValues: collection.decks.map { ($0.id, $0.name) })

                return collection.cards.compactMap { card -> AnkiStudyCard? in
                    guard let note = notes[card.noteID], let type = types[note.noteTypeID] else { return nil }
                    return AnkiStudyCard(
                        importID: summary.id,
                        card: card,
                        note: note,
                        noteType: type,
                        deckName: deckNames[card.deckID] ?? summary.filename,
                        mediaDirectory: media
                    )
                }
            }.value
            result.append(contentsOf: importCards)
        }
        return result
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
                let deckCards = collection.cards.filter { $0.deckID == deck.sourceDeckID }.compactMap { card -> AnkiStudyCard? in
                    guard let note = notes[card.noteID], let type = types[note.noteTypeID] else { return nil }
                    return AnkiStudyCard(importID: deck.importID, card: card, note: note, noteType: type, deckName: deck.title, mediaDirectory: media)
                }
                return AnkiStudyCard.orderedByAnkiPosition(deckCards)
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
