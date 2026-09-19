import Foundation

public struct AnkiDeck: Codable, Sendable, Identifiable {
    public let id: Int64
    public let name: String
}

public struct AnkiTemplate: Codable, Sendable {
    public let ordinal: Int
    public let name: String
    public let question: String
    public let answer: String
}

public struct AnkiNoteType: Codable, Sendable, Identifiable {
    public let id: Int64
    public let name: String
    public let isCloze: Bool
    public let fields: [String]
    public let templates: [AnkiTemplate]
    public let css: String
}

public struct AnkiNote: Codable, Sendable, Identifiable {
    public let id: Int64
    public let guid: String
    public let noteTypeID: Int64
    public let fields: [String]
    public let tags: [String]
    public var parsedFields: [AnkiContent]? = nil
}

/// Meaning of `revlog.ease` for answer rows. Manual/reschedule rows may use 0.
public enum AnkiReviewRating: Int, Codable, Sendable {
    case again = 1, hard = 2, good = 3, easy = 4
}

/// Values used by Anki's `revlog.type` column.
public enum AnkiReviewKind: Int, Codable, Sendable {
    case learning = 0
    case review = 1
    case relearning = 2
    case filtered = 3
    case manual = 4
    case rescheduled = 5
}

public struct AnkiReviewLogEntry: Codable, Sendable, Identifiable {
    public let id: Int64
    public let cardID: Int64
    public let updateSequenceNumber: Int64
    public let ease: Int
    public let interval: Int64
    public let previousInterval: Int64
    public let factor: Int64
    public let answerTimeMilliseconds: Int64
    public let type: Int

    public var rating: AnkiReviewRating? { AnkiReviewRating(rawValue: ease) }
    public var kind: AnkiReviewKind? { AnkiReviewKind(rawValue: type) }
    public var reviewedAt: Date { Date(timeIntervalSince1970: Double(id) / 1_000) }
}

public struct AnkiCard: Codable, Sendable, Identifiable {
    public let id: Int64
    public let noteID: Int64
    public let deckID: Int64
    public let ordinal: Int
    /// Original Anki card scheduling values.
    public let scheduling: [String: Int64]
    /// Chronological rows from `revlog` for this card. Nil in older saved imports.
    public var reviewHistory: [AnkiReviewLogEntry]? = nil
}

public struct AnkiMedia: Codable, Sendable {
    public let name: String
    public let size: Int
}

public struct AnkiCollection: Codable, Sendable {
    public let decks: [AnkiDeck]
    public let noteTypes: [AnkiNoteType]
    public var notes: [AnkiNote]
    public let cards: [AnkiCard]
    /// `col.crt`, in Unix seconds. Review/day-learning `due` values are relative to it.
    public var creationTime: Int64? = nil
    public var media: [AnkiMedia] = []
    public var warnings: [String] = []
}

public enum AnkiImportError: LocalizedError {
    case invalid(String)
    case limit
    case unsupported(Int)

    public var errorDescription: String? {
        switch self {
        case .invalid(let detail): "Не удалось импортировать Anki: \(detail)"
        case .limit: "Колода превышает лимит импорта: 512 МБ для базы, 256 МБ на медиафайл, 4 ГБ всего."
        case .unsupported(let version): "Версия пакета Anki \(version) пока не поддерживается."
        }
    }
}
