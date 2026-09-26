import Foundation

extension TatoebaWordExampleProvider {
    func loadRemoteExamples(for card: WordStudyCard, limit: Int) async -> [WordUsageExample] {
        guard let url = TatoebaEndpoint.sentences(for: card.word) else {
            return []
        }

        do {
            let (data, response) = try await session.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                return []
            }

            let payload = try JSONDecoder().decode(TatoebaSentenceResponse.self, from: data)
            return payload.data
                .filter { !$0.isUnapproved && $0.text.contains(card.word) && $0.attribution != nil }
                .prefix(limit)
                .map { sentence in
                    WordUsageExample(
                        sentence: sentence.text,
                        reading: Self.fallbackReading(for: card, in: sentence.text),
                        meaning: sentence.preferredEnglishTranslation?.text,
                        attribution: sentence.attribution,
                        translationAttribution: sentence.preferredEnglishTranslation?.attribution
                    )
                }
        } catch {
            return []
        }
    }

    static func fallbackReading(for card: WordStudyCard, in sentence: String) -> String? {
        guard card.word != card.reading, sentence.contains(card.word) else {
            return nil
        }

        return "\(card.word): \(card.reading)"
    }

    func loadRemoteKanjiExamples(for kanji: String, limit: Int) async -> [KanjiExample] {
        guard let url = TatoebaEndpoint.sentences(for: kanji) else {
            return []
        }

        do {
            let (data, response) = try await session.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                return []
            }

            let payload = try JSONDecoder().decode(TatoebaSentenceResponse.self, from: data)
            return payload.data
                .filter { !$0.isUnapproved && $0.text.contains(kanji) && $0.attribution != nil }
                .prefix(limit)
                .map { sentence in
                    KanjiExample(
                        word: sentence.text,
                        reading: "",
                        meaning: sentence.preferredEnglishTranslation?.text ?? "",
                        attribution: sentence.attribution,
                        translationAttribution: sentence.preferredEnglishTranslation?.attribution
                    )
                }
        } catch {
            return []
        }
    }
}
