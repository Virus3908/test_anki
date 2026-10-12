import Foundation

nonisolated struct FuriganaSegment: Codable, Hashable, Sendable {
    let text: String
    let reading: String?
}

/// Raw Tatoeba metadata is retained for attribution and future parser improvements.
nonisolated struct TatoebaTranscription: Codable, Hashable, Sendable {
    let text: String
    let script: String
    let type: String
    var needsReview: Bool? = nil
    var html: String? = nil
    var editor: String? = nil
    var modified: String? = nil
}

nonisolated struct ExampleFurigana: Codable, Hashable, Sendable {
    /// nil means a failed refresh; [] means a successful response with no transcriptions.
    let transcriptions: [TatoebaTranscription]?
    let checkedAt: Date

    var needsRefresh: Bool {
        transcriptions == nil && Date().timeIntervalSince(checkedAt) >= 24 * 60 * 60
    }

    func segments(for text: String) -> [FuriganaSegment] {
        for transcription in transcriptions ?? [] where transcription.script == "Hrkt" && transcription.type == "altscript" {
            if let segments = FuriganaParser.parse(transcription.text, original: text) { return segments }
        }
        return [FuriganaSegment(text: text, reading: nil)]
    }
}

nonisolated enum FuriganaParser {
    /// Tatoeba uses [今日|きょう] (group ruby) and [学校|がっ|こう] (per-character ruby).
    /// Only explicit markup is interpreted. No dictionary guesses, HTML parsing or normalization.
    static func parse(_ transcription: String, original: String) -> [FuriganaSegment]? {
        guard transcription.count <= 20_000 else { return nil }
        var result: [FuriganaSegment] = []
        var plain = ""
        var index = transcription.startIndex
        func flush() {
            if !plain.isEmpty { result.append(FuriganaSegment(text: plain, reading: nil)); plain = "" }
        }
        while index < transcription.endIndex {
            let character = transcription[index]
            if character != "[" {
                // Reject stray markup; a literal bracket in the original falls back safely.
                guard character != "]", character != "|" else { return nil }
                plain.append(character)
                index = transcription.index(after: index)
                continue
            }
            flush()
            guard let end = transcription[index...].firstIndex(of: "]") else { return nil }
            let start = transcription.index(after: index)
            let fields = transcription[start..<end].split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 2, !fields[0].isEmpty, !fields[0].contains("[") else { return nil }
            let base = fields[0]
            let readings = Array(fields.dropFirst())
            guard readings.allSatisfy({ $0.isEmpty || isKanaReading($0) }) else { return nil }
            if readings.count == 1 {
                result.append(FuriganaSegment(text: base, reading: readings[0].isEmpty || readings[0] == base ? nil : readings[0]))
            } else {
                guard readings.count == base.count else { return nil }
                for (character, reading) in zip(base, readings) {
                    let text = String(character)
                    result.append(FuriganaSegment(text: text, reading: reading.isEmpty || reading == text ? nil : reading))
                }
            }
            index = transcription.index(after: end)
        }
        flush()
        // Compare bytes too: Swift String equality alone permits canonical equivalence.
        guard result.map(\.text).joined().utf8.elementsEqual(original.utf8) else { return nil }
        return result
    }

    private static func isKanaReading(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy {
            (0x3041...0x3096).contains($0.value) || (0x3099...0x309E).contains($0.value)
                || (0x30A1...0x30FA).contains($0.value) || (0x30FC...0x30FE).contains($0.value)
        }
    }
}
