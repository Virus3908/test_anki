import Foundation

nonisolated enum BundledKanjiVG {
    private struct IndexEntry: Decodable, Sendable {
        let offset: Int
        let length: Int
    }

    private struct Archive: Sendable {
        let data: Data
        let index: [String: IndexEntry]

        init(bundle: Bundle = .main) throws {
            guard
                let dataURL = bundle.url(forResource: "kanjivg-20250816", withExtension: "bin"),
                let indexURL = bundle.url(forResource: "kanjivg-20250816-index", withExtension: "json")
            else {
                throw CocoaError(.fileReadNoSuchFile)
            }

            data = try Data(contentsOf: dataURL, options: .mappedIfSafe)
            index = try JSONDecoder().decode(
                [String: IndexEntry].self,
                from: Data(contentsOf: indexURL)
            )
        }

        func strokes(fileName: String) throws -> [KanjiStroke] {
            guard let entry = index[fileName] else {
                throw ArchiveError.missingCharacter
            }

            let end = entry.offset + entry.length
            guard entry.offset >= 0, entry.length >= 0, end <= data.count else {
                throw ArchiveError.invalidData
            }

            var cursor = entry.offset
            var pathDataValues: [String] = []
            while cursor < end {
                guard cursor + 4 <= end else { throw ArchiveError.invalidData }

                var pathLength = 0
                for byte in data[cursor..<(cursor + 4)] {
                    pathLength = (pathLength << 8) | Int(byte)
                }
                cursor += 4

                guard pathLength > 0, cursor + pathLength <= end else {
                    throw ArchiveError.invalidData
                }

                let pathData = String(decoding: data[cursor..<(cursor + pathLength)], as: UTF8.self)
                pathDataValues.append(pathData)
                cursor += pathLength
            }

            let strokes = SVGStrokeExtractor.strokes(fromPathData: pathDataValues)
            guard !strokes.isEmpty else { throw ArchiveError.missingCharacter }
            return strokes
        }
    }

    private enum ArchiveError: Error {
        case invalidData
        case missingCharacter
    }

    private static let archive = try? Archive()

    static func strokes(for character: String) throws -> [KanjiStroke] {
        guard let archive else { throw ArchiveError.invalidData }
        return try archive.strokes(fileName: fileName(for: character))
    }

    static func fileName(for character: String) -> String {
        guard character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first else {
            return "00000.svg"
        }

        return String(format: "%05x.svg", scalar.value)
    }
}
