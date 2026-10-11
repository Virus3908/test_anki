import Foundation

nonisolated struct BundledKanaMetadata: Decodable, Sendable {
    let character: String
    let reading: String
    let script: KanaDeck
    let order: Int

    func makeCard() throws -> KanaStudyCard {
        let parts = try character.map { try BundledKanaDrawing.card(for: String($0)) }
        return KanaStudyCard(character: character, reading: reading, script: script, drawingCards: parts)
    }

    static func cards(for deck: KanaDeck, from metadata: [Self]) throws -> [KanaStudyCard] {
        try metadata.filter { $0.script == deck }.sorted { $0.order < $1.order }.map { try $0.makeCard() }
    }

    static func validate(_ metadata: [Self]) throws {
        guard !metadata.isEmpty,
              Set(metadata.map(\.character)).count == metadata.count,
              metadata.allSatisfy({ !$0.character.isEmpty && !$0.reading.isEmpty && $0.order > 0 }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        for deck in KanaDeck.allCases {
            let orders = metadata.filter { $0.script == deck }.map(\.order).sorted()
            guard !orders.isEmpty, orders == Array(1...orders.count) else {
                throw CocoaError(.fileReadCorruptFile)
            }
        }
    }
}
