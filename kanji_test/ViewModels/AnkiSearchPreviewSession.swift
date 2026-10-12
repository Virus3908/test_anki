import Foundation
import AnkiImport

/// Owned by the search screen. Retains only the active import, until the card
/// viewer closes; it is separate from the persistent compact search index.
@MainActor
final class AnkiSearchPreviewSession {
    private(set) var importID: String?
    private var lookup: AnkiCollectionLookup?
    private var media: URL?
    private var generation = 0
    private var worker: Task<(AnkiCollectionLookup, URL), Error>?

    func close() {
        generation += 1
        worker?.cancel()
        worker = nil
        lookup = nil
        media = nil
        importID = nil
    }

    func card(_ record: AnkiSearchRecord, summary: AnkiImportSummary,
              repository: any AnkiLibraryPersisting) async throws -> AnkiStudyCard {
        try Task.checkCancellation()
        if importID != summary.id || lookup == nil { close() }
        generation += 1
        let token = generation
        worker?.cancel()
        worker = nil
        if let lookup, let media {
            return try lookup.studyCard(record, media: media)
        }
        let task = Task.detached(priority: .userInitiated) {
            let collection = try await repository.collection(summary)
            try Task.checkCancellation()
            let media = try await repository.mediaDirectory(summary)
            return (try AnkiCollectionLookup(collection), media)
        }
        importID = summary.id
        worker = task
        do {
            let loaded = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            try Task.checkCancellation()
            guard generation == token else { throw CancellationError() }
            lookup = loaded.0
            media = loaded.1
            importID = summary.id
            worker = nil
            return try loaded.0.studyCard(record, media: loaded.1)
        } catch {
            if generation == token { close() }
            throw error
        }
    }

    deinit { worker?.cancel() }
}

nonisolated struct AnkiCollectionLookup: Sendable {
    let cards: [Int64: AnkiCard]
    let notes: [Int64: AnkiNote]
    let types: [Int64: AnkiNoteType]
    let deckNames: [Int64: String]

    init(_ collection: AnkiCollection) throws {
        var cards: [Int64: AnkiCard] = [:]
        var notes: [Int64: AnkiNote] = [:]
        var types: [Int64: AnkiNoteType] = [:]
        var names: [Int64: String] = [:]
        for card in collection.cards {
            try Task.checkCancellation()
            cards[card.id] = cards[card.id] ?? card
        }
        for note in collection.notes {
            try Task.checkCancellation()
            notes[note.id] = notes[note.id] ?? note
        }
        for type in collection.noteTypes {
            try Task.checkCancellation()
            types[type.id] = types[type.id] ?? type
        }
        for deck in collection.decks {
            try Task.checkCancellation()
            names[deck.id] = deck.name
        }
        self.cards = cards; self.notes = notes; self.types = types; deckNames = names
    }

    func studyCard(_ record: AnkiSearchRecord, media: URL) throws -> AnkiStudyCard {
        try Task.checkCancellation()
        guard let card = cards[record.cardID], let note = notes[card.noteID],
              let type = types[note.noteTypeID] else {
            throw AnkiImportError.invalid("карточка отсутствует в импорте")
        }
        return AnkiStudyCard(importID: record.importID, card: card, note: note,
            noteType: type, deckName: deckNames[card.deckID] ?? record.deckName, mediaDirectory: media)
    }

    static func deckCards(collection: AnkiCollection, media: URL, deck: AnkiDeckReference) throws -> [AnkiStudyCard] {
        let lookup = try Self(collection)
        var result: [AnkiStudyCard] = []
        for card in collection.cards {
            try Task.checkCancellation()
            guard card.deckID == deck.sourceDeckID,
                  let note = lookup.notes[card.noteID], let type = lookup.types[note.noteTypeID] else { continue }
            result.append(AnkiStudyCard(importID: deck.importID, card: card, note: note,
                noteType: type, deckName: deck.title, mediaDirectory: media))
        }
        try Task.checkCancellation()
        let ordered = AnkiStudyCard.orderedByAnkiPosition(result)
        try Task.checkCancellation()
        return ordered
    }
}
