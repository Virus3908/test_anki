import Foundation

@MainActor
private enum TatoebaFuriganaRequests {
    struct Key: Hashable {
        let session: ObjectIdentifier
        let sentenceID: Int
    }
    static var pending: [Key: Task<TatoebaSentence?, Never>] = [:]

    static func sentence(id: Int, session: URLSession) async -> TatoebaSentence? {
        let key = Key(session: ObjectIdentifier(session), sentenceID: id)
        if let task = pending[key] { return await task.value }
        let task = Task<TatoebaSentence?, Never> {
            struct Response: Decodable { let data: TatoebaSentence }
            guard let url = TatoebaEndpoint.sentence(id: id) else { return nil }
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
                return try JSONDecoder().decode(Response.self, from: data).data
            } catch { return nil }
        }
        pending[key] = task
        let result = await task.value
        pending[key] = nil
        return result
    }
}

extension TatoebaWordExampleProvider {
    private func updatedFurigana(_ current: ExampleFurigana?, text: String, attribution: TatoebaAttribution?) async -> ExampleFurigana? {
        guard let attribution, current?.needsRefresh ?? true else { return current }
        let sentence = await TatoebaFuriganaRequests.sentence(id: attribution.sentenceID, session: session)
        guard let sentence, sentence.id == attribution.sentenceID,
              sentence.text.utf8.elementsEqual(text.utf8), sentence.attribution == attribution,
              !sentence.isUnapproved else {
            return ExampleFurigana(transcriptions: nil, checkedAt: Date())
        }
        return ExampleFurigana(transcriptions: sentence.transcriptions ?? [], checkedAt: Date())
    }

    func enrich(_ examples: [WordUsageExample]) async -> [WordUsageExample] {
        var result: [WordUsageExample] = []
        for var example in examples {
            example.furigana = await updatedFurigana(example.furigana, text: example.sentence, attribution: example.attribution)
            result.append(example)
        }
        return result
    }

    func enrich(_ examples: [KanjiExample]) async -> [KanjiExample] {
        var result: [KanjiExample] = []
        for var example in examples {
            example.furigana = await updatedFurigana(example.furigana, text: example.word, attribution: example.attribution)
            result.append(example)
        }
        return result
    }
}
