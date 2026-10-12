import Foundation

extension TatoebaWordExampleProvider {
    private func updatedFurigana(_ current: ExampleFurigana?, text: String, attribution: TatoebaAttribution?) async -> ExampleFurigana? {
        guard let attribution, current?.needsRefresh ?? true else { return current }
        guard !Task.isCancelled, let url = TatoebaEndpoint.sentence(id: attribution.sentenceID) else { return current }
        struct Response: Decodable { let data: TatoebaSentence }
        let data = await TatoebaRequests.shared.data(from: url, session: session, kind: .transcription)
        guard !Task.isCancelled else { return current }
        let sentence = data.flatMap { try? JSONDecoder().decode(Response.self, from: $0).data }
        guard let sentence, sentence.id == attribution.sentenceID,
              sentence.text.utf8.elementsEqual(text.utf8), sentence.attribution == attribution,
              !sentence.isUnapproved else {
            return ExampleFurigana(transcriptions: nil, checkedAt: Date())
        }
        return ExampleFurigana(transcriptions: sentence.transcriptions ?? [], checkedAt: Date())
    }

    func enrich(_ examples: [WordUsageExample]) async -> [WordUsageExample] {
        await enrichInOrder(examples) { example in
            var updated = example
            updated.furigana = await updatedFurigana(example.furigana, text: example.sentence, attribution: example.attribution)
            return updated
        }
    }

    func enrich(_ examples: [KanjiExample]) async -> [KanjiExample] {
        await enrichInOrder(examples) { example in
            var updated = example
            updated.furigana = await updatedFurigana(example.furigana, text: example.word, attribution: example.attribution)
            return updated
        }
    }

    /// Keep only three child tasks alive, inserting results into original slots.
    private func enrichInOrder<Example: Sendable>(_ examples: [Example],
        update: @escaping @MainActor @Sendable (Example) async -> Example) async -> [Example] {
        guard !Task.isCancelled else { return examples }
        return await withTaskGroup(of: (Int, Example).self) { group in
            var result = examples
            var next = 0
            func enqueue(_ index: Int) {
                let example = examples[index]
                group.addTask { (index, await update(example)) }
            }
            while next < min(3, examples.count) { enqueue(next); next += 1 }
            while let (index, example) = await group.next() {
                guard !Task.isCancelled else { group.cancelAll(); return examples }
                result[index] = example
                if next < examples.count { enqueue(next); next += 1 }
            }
            return result
        }
    }
}
