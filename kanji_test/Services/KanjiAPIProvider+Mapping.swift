import Foundation

extension KanjiAPIProvider {
    func loadCard(for kanji: String) async throws -> KanjiCard {
        async let detailData = session.data(from: KanjiAPIEndpoint.kanjiDetail(kanji)).0
        async let svgData = session.data(from: KanjiAPIEndpoint.kanjiVGSVG(kanji)).0

        let detail = try JSONDecoder().decode(RemoteKanjiDetail.self, from: try await detailData)
        let svgText = String(decoding: try await svgData, as: UTF8.self)
        let strokes = SVGStrokeExtractor.strokes(from: svgText)

        guard !strokes.isEmpty else {
            throw RemoteKanjiError.missingStrokes
        }

        let loadedExamples = await loadExamples(for: kanji)

        return KanjiCard(
            kanji: detail.kanji,
            meanings: detail.meanings,
            onyomi: detail.onReadings,
            kunyomi: detail.kunReadings,
            examples: loadedExamples,
            source: KanjiSource(
                name: "kanjiapi.dev + KanjiVG",
                file: KanjiAPIEndpoint.svgFileName(for: kanji),
                license: "KanjiVG: Creative Commons Attribution-Share Alike 3.0"
            ),
            strokes: strokes,
            grade: detail.grade,
            jlpt: detail.jlpt
        )
    }

    func loadExamples(for kanji: String) async -> [KanjiExample] {
        do {
            let (data, _) = try await withTimeout(seconds: 3) {
                try await session.data(from: KanjiAPIEndpoint.words(kanji))
            }
            let entries = try JSONDecoder().decode([RemoteWordEntry].self, from: data)
            var examples: [KanjiExample] = []

            for entry in entries.prefix(30) {
                let englishMeaning = entry.meanings.flatMap(\.glosses).prefix(2).joined(separator: ", ")

                for variant in entry.variants where variant.written.contains(kanji) {
                    examples.append(KanjiExample(word: variant.written, reading: variant.pronounced, meaning: englishMeaning))

                    if examples.count == 6 {
                        return examples
                    }
                }
            }

            return examples
        } catch {
            return []
        }
    }
}
