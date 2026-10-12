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
    @ObservationIgnored private weak var searchPreviewSession: AnkiSearchPreviewSession?
    typealias DeckCardBuilder = @Sendable (AnkiCollection, URL, AnkiDeckReference) async throws -> [AnkiStudyCard]
    private let deckCardBuilder: DeckCardBuilder
    private(set) var searchUnavailableImports: [AnkiImportSummary] = []
    private var openToken: UUID { request.id }
    private var isLoading = false
    /// `nil` means the bootstrap could not run yet (e.g. review progress is not loaded);
    /// the migration must then stay unmarked so it is retried later.
    @ObservationIgnored var bootstrapScheduling: ((AnkiCollection, String) async throws -> Int?)?

    init(repository: any AnkiLibraryPersisting = AnkiRepository(),
         deckCardBuilder: @escaping DeckCardBuilder = { try AnkiCollectionLookup.deckCards(collection: $0, media: $1, deck: $2) }) {
        self.repository = repository
        self.deckCardBuilder = deckCardBuilder
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

    func deleteImport(_ deck: AnkiDeckReference, trainingSession: TrainingSessionViewModel) async -> Bool {
        guard !isDeletingDeck, !isImporting else { return false }
        isDeletingDeck = true
        defer { isDeletingDeck = false }
        do {
            try await trainingSession.deleteAnkiImportProgress(importID: deck.importID) {
                try await repository.deleteImport(id: deck.importID)
            }
            if searchPreviewSession?.importID == deck.importID { searchPreviewSession?.close() }
            imports.removeAll { $0.id == deck.importID }
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
            do { try Task.checkCancellation(); _ = try await migrateScheduling(summary) }
            catch is CancellationError { return }
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
        try Task.checkCancellation()
        try await repository.markSchedulingMigration(importID: summary.id, version: AnkiSchedulingMigrator.version)
        if let index = imports.firstIndex(where: { $0.id == summary.id }) {
            imports[index].schedulingMigrationVersion = AnkiSchedulingMigrator.version
        }
        return count
    }

    func open(_ summary: AnkiImportSummary) async throws -> (AnkiCollection, URL) {
        let collection = try await repository.collection(summary)
        try Task.checkCancellation()
        let media = try await repository.mediaDirectory(summary)
        try Task.checkCancellation()
        return (collection, media)
    }

    func recordsForSearch() async throws -> [AnkiSearchRecord] {
        if !isLoaded {
            // Search needs the library index, not scheduling migration of every import.
            imports = try await repository.load()
            try Task.checkCancellation()
            isLoaded = true
        }
        var records: [AnkiSearchRecord] = []
        var unavailable: [AnkiImportSummary] = []
        for summary in imports {
            try Task.checkCancellation()
            do { records.append(contentsOf: try await repository.searchRecords(summary)) }
            catch is CancellationError { throw CancellationError() }
            catch {
                try Task.checkCancellation()
                unavailable.append(summary)
            }
        }
        try Task.checkCancellation()
        searchUnavailableImports = unavailable
        return records
    }

    func cardForSearchResult(_ record: AnkiSearchRecord,
                             session: AnkiSearchPreviewSession) async throws -> AnkiStudyCard {
        guard let summary = imports.first(where: { $0.id == record.importID }) else {
            session.close()
            throw AnkiImportError.invalid("импорт отсутствует в библиотеке")
        }
        searchPreviewSession = session
        let card = try await session.card(record, summary: summary, repository: repository)
        try Task.checkCancellation()
        guard imports.contains(where: { $0.id == summary.id }) else {
            session.close()
            throw AnkiImportError.invalid("импорт отсутствует в библиотеке")
        }
        return card
    }

    func openDeck(_ deck: AnkiDeckReference) async {
        beginOpening(deck)
        let task = request.task
        await withTaskCancellationHandler { await task?.value } onCancel: { task?.cancel() }
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
            try Task.checkCancellation()
            guard openToken == token else { return }
            let builder = deckCardBuilder
            let worker = Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                return try await builder(collection, media, deck)
            }
            let cards = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
            guard openToken == token, !Task.isCancelled else { return }
            previewCards = cards
        } catch is CancellationError { }
        catch { if openToken == token, !Task.isCancelled { loadError = error.localizedDescription } }
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
