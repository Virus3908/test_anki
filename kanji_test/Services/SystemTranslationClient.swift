import Foundation
import Translation

enum SystemTranslationClient {
    static func translate(_ meanings: [String]) async throws -> [String] {
        guard !meanings.isEmpty else {
            return []
        }

        let session = TranslationSession(
            installedSource: Locale.Language(identifier: "en"),
            target: Locale.Language(identifier: "ru")
        )
        let requests = meanings.map { TranslationSession.Request(sourceText: $0) }
        let responses = try await session.translations(from: requests)
        let translated = responses.map { $0.targetText.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard translated.count == meanings.count else {
            return RussianMeaningDictionary.translate(meanings)
        }

        return translated.enumerated().map { index, value in
            value.isEmpty || value.caseInsensitiveCompare(meanings[index]) == .orderedSame
                ? RussianMeaningDictionary.translate([meanings[index]]).first ?? value
                : value
        }
    }
}
