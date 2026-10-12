import Foundation

actor BundledStudyData {
    static let shared = BundledStudyData()
    private let bundle: Bundle

    init(bundle: Bundle = .main) { self.bundle = bundle }

    private var words: [WordDictionaryEntry]?
    private var kanaMetadata: [BundledKanaMetadata]?
    private var kanaCards: [KanaDeck: [KanaStudyCard]] = [:]
    private var kanjiMetadata: [BundledKanjiMetadata]?
    private var kanjiByCharacter: [String: BundledKanjiMetadata]?
    private var kanjiCards: [String: KanjiCard] = [:]

    /// Metadata is decoded/indexed once; geometry is built only on demand and
    /// shared by subsequent word/deck loads through Swift's value storage.
    func bundledKanjiCards(characters: Set<String>) throws -> [KanjiCard] {
        if kanjiByCharacter == nil {
            kanjiByCharacter = Dictionary(try bundledKanjiMetadata().map { ($0.kanji, $0) },
                uniquingKeysWith: { first, _ in first })
        }
        return try characters.sorted().compactMap { character in
            try Task.checkCancellation()
            if let cached = kanjiCards[character] { return cached }
            guard let metadata = kanjiByCharacter?[character] else { return nil }
            let card = metadata.makeCard()
            kanjiCards[character] = card
            return card
        }
    }


    func wordEntries() throws -> [WordDictionaryEntry] {
        if let words { return words }
        let loaded: [WordDictionaryEntry] = try decode("word-data")
        words = loaded
        return loaded
    }

    func bundledKanjiMetadata() throws -> [BundledKanjiMetadata] {
        if let kanjiMetadata { return kanjiMetadata }
        let loaded: [BundledKanjiMetadata] = try decode("kanji-metadata")
        kanjiMetadata = loaded
        return loaded
    }

    func bundledKanaMetadata() throws -> [BundledKanaMetadata] {
        if let kanaMetadata { return kanaMetadata }
        let loaded: [BundledKanaMetadata] = try decode("kana-metadata")
        try BundledKanaMetadata.validate(loaded)
        kanaMetadata = loaded
        return loaded
    }

    func bundledKanaCards(deck: KanaDeck) throws -> [KanaStudyCard] {
        if let cached = kanaCards[deck] { return cached }
        let metadata = try bundledKanaMetadata()
        let cards = try BundledKanaMetadata.cards(for: deck, from: metadata)
        guard cards.allSatisfy({ !$0.strokes.isEmpty }) else { throw CocoaError(.fileReadCorruptFile) }
        kanaCards[deck] = cards
        return cards
    }

    private func decode<Value: Decodable>(_ resource: String) throws -> Value {
        try Self.decodeResource(resource, bundle: bundle)
    }

    nonisolated static func decodeResource<Value: Decodable>(_ resource: String, bundle: Bundle = .main) throws -> Value {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
    }
}
