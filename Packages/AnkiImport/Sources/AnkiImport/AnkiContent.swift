import Foundation

/// A lossless source is kept in AnkiNote.fields; this is a portable, native-display projection.
public struct AnkiContent: Codable, Sendable, Equatable {
    public var blocks: [AnkiContentBlock]
    public var warnings: [String]
    public var textRuns: [String] {
        blocks.flatMap { $0.runs.map(\.text) + AnkiContent(blocks: $0.children, warnings: []).textRuns }
    }

    public func replacingTexts(_ translations: [String: String]) -> AnkiContent {
        var result = self
        result.blocks = blocks.map { block in
            var block = block
            block.runs = block.runs.map { run in
                var run = run
                if let translated = translations[run.text] { run.text = translated }
                return run
            }
            block.children = AnkiContent(blocks: block.children, warnings: []).replacingTexts(translations).blocks
            return block
        }
        return result
    }
    public var plainText: String {
        blocks.map { block in
            if block.kind == .hint { return block.label + "\n" + AnkiContent(blocks: block.children, warnings: []).plainText }
            return block.runs.map(\.text).joined()
        }.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

public struct AnkiContentBlock: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case text, image, audio, video, divider, input, hint }
    public var kind: Kind
    public var runs: [AnkiTextRun] = []
    /// Local filename only. Paths and external URLs are never opened by the native renderer.
    public var filename: String? = nil
    public var label: String = ""
    public var children: [AnkiContentBlock] = []
}

public struct AnkiTextRun: Codable, Sendable, Equatable {
    public var text: String
    public var bold = false
    public var italic = false
    public var underline = false
    public var strikethrough = false
    public var cloze = false
}
