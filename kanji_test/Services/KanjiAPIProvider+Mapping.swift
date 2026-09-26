import Foundation

extension KanjiAPIProvider {
    func loadExamples(for kanji: String) async -> [KanjiExample] {
        await TatoebaWordExampleProvider(session: session).loadRemoteKanjiExamples(for: kanji, limit: 6)
    }
}
