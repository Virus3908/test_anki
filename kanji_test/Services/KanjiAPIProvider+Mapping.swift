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

        return KanjiCard(
            kanji: detail.kanji,
            meanings: detail.meanings,
            onyomi: detail.onReadings,
            kunyomi: detail.kunReadings,
            examples: [],
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
        await TatoebaWordExampleProvider(session: session).loadRemoteKanjiExamples(for: kanji, limit: 6)
    }
}
