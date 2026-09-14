import Foundation

struct OutputCard: Codable {
    let kanji: String
    let meanings: [String]
    let onyomi: [String]
    let kunyomi: [String]
    let examples: [OutputExample]
    let source: OutputSource
    let strokes: [OutputStroke]
    let grade: Int?
    let jlpt: Int?
    let translationState: String?
}

struct OutputExample: Codable {
    let word: String
    let reading: String
    let meaning: String
}

struct OutputSource: Codable {
    let name: String
    let file: String
    let license: String
}

struct OutputStroke: Codable {
    let order: Int
    let path: String
    let start: [Double]
    let end: [Double]
    let axis: String
}

struct Detail: Decodable {
    let kanji: String
    let meanings: [String]
    let onReadings: [String]
    let kunReadings: [String]
    let grade: Int?
    let jlpt: Int?

    enum CodingKeys: String, CodingKey {
        case kanji
        case meanings
        case onReadings = "on_readings"
        case kunReadings = "kun_readings"
        case grade
        case jlpt
    }
}

let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("kanji_test/kanji_test/kanji-all.json")
let apiBase = "https://kanjiapi.dev/v1"
let svgBase = "https://raw.githubusercontent.com/KanjiVG/kanjivg/master/kanji"
let session = URLSession.shared
let decoder = JSONDecoder()
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

func fetch(_ url: URL) async throws -> Data {
    let (data, response) = try await session.data(from: url)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        throw URLError(.badServerResponse)
    }
    return data
}

func svgFileName(for kanji: String) -> String {
    guard let scalar = kanji.unicodeScalars.first else {
        return "00000.svg"
    }

    return String(format: "%05x.svg", scalar.value)
}

func pathValues(in svg: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: #"<path[^>]*\sd=\"([^\"]+)\""#) else {
        return []
    }

    let range = NSRange(svg.startIndex..<svg.endIndex, in: svg)
    return regex.matches(in: svg, range: range).compactMap { match in
        guard let matchRange = Range(match.range(at: 1), in: svg) else {
            return nil
        }

        return String(svg[matchRange])
    }
}

func numbers(in text: String) -> [Double] {
    var values: [Double] = []
    var token = ""
    var previous: Character?

    for character in text {
        let startsSignedNumber = (character == "-" || character == "+") && previous != nil && previous != "e" && previous != "E"
        if character == "," || character.isWhitespace || startsSignedNumber {
            if let value = Double(token) {
                values.append(value)
            }
            token = startsSignedNumber ? String(character) : ""
        } else {
            token.append(character)
        }
        previous = character
    }

    if let value = Double(token) {
        values.append(value)
    }
    return values
}

func segments(in pathData: String) -> [(command: String, arguments: String)] {
    let characters = Array(pathData)
    var result: [(String, String)] = []
    var index = 0

    while index < characters.count {
        let command = characters[index]
        guard command.isLetter else {
            index += 1
            continue
        }

        let start = index + 1
        index = start
        while index < characters.count, !characters[index].isLetter {
            index += 1
        }
        result.append((String(command), String(characters[start..<index])))
    }

    return result
}

func points(in pathData: String) -> [(x: Double, y: Double)] {
    var points: [(Double, Double)] = []
    var current = (x: 0.0, y: 0.0)

    for segment in segments(in: pathData) {
        let values = numbers(in: segment.arguments)
        switch segment.command {
        case "M", "L":
            for index in stride(from: 0, to: values.count - 1, by: 2) {
                current = (values[index], values[index + 1])
                points.append(current)
            }
        case "m", "l":
            for index in stride(from: 0, to: values.count - 1, by: 2) {
                current = (current.x + values[index], current.y + values[index + 1])
                points.append(current)
            }
        case "C":
            for index in stride(from: 0, to: values.count - 5, by: 6) {
                points.append((values[index], values[index + 1]))
                points.append((values[index + 2], values[index + 3]))
                current = (values[index + 4], values[index + 5])
                points.append(current)
            }
        case "c":
            for index in stride(from: 0, to: values.count - 5, by: 6) {
                points.append((current.x + values[index], current.y + values[index + 1]))
                points.append((current.x + values[index + 2], current.y + values[index + 3]))
                current = (current.x + values[index + 4], current.y + values[index + 5])
                points.append(current)
            }
        default:
            continue
        }
    }

    return points
}

func stroke(from pathData: String, order: Int) -> OutputStroke? {
    let strokePoints = points(in: pathData)
    guard let start = strokePoints.first, let end = strokePoints.last else {
        return nil
    }

    let minX = strokePoints.map(\.x).min() ?? start.x
    let maxX = strokePoints.map(\.x).max() ?? start.x
    let minY = strokePoints.map(\.y).min() ?? start.y
    let maxY = strokePoints.map(\.y).max() ?? start.y
    let width = maxX - minX
    let height = maxY - minY
    let axis: String
    if width > height * 1.5 {
        axis = "horizontal"
    } else if height > width * 1.5 {
        axis = "vertical"
    } else {
        axis = "corner"
    }

    return OutputStroke(order: order, path: pathData, start: [start.x, start.y], end: [end.x, end.y], axis: axis)
}

func loadExistingCards() -> [String: OutputCard] {
    guard let data = try? Data(contentsOf: outputURL),
          let cards = try? decoder.decode([OutputCard].self, from: data) else {
        return [:]
    }

    return Dictionary(cards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })
}

let listURL = URL(string: "\(apiBase)/kanji/all")!
let allKanji = try await decoder.decode([String].self, from: fetch(listURL))
var cardsByKanji = loadExistingCards()
let maxConcurrentRequests = 20
var nextIndex = 0

print("Official all-kanji list: \(allKanji.count)")
print("Already generated: \(cardsByKanji.count)")

try await withThrowingTaskGroup(of: OutputCard?.self) { group in
    func enqueueNext() {
        while nextIndex < allKanji.count {
            let kanji = allKanji[nextIndex]
            nextIndex += 1
            guard cardsByKanji[kanji] == nil else {
                continue
            }

            group.addTask {
                do {
                    let detailURL = URL(string: "\(apiBase)/kanji/\(kanji)")!
                    let fileName = svgFileName(for: kanji)
                    let svgURL = URL(string: "\(svgBase)/\(fileName)")!
                    async let detailData = fetch(detailURL)
                    async let svgData = fetch(svgURL)

                    let detail = try await decoder.decode(Detail.self, from: detailData)
                    let svg = String(decoding: try await svgData, as: UTF8.self)
                    let strokes = pathValues(in: svg).enumerated().compactMap { stroke(from: $0.element, order: $0.offset + 1) }
                    guard !strokes.isEmpty else {
                        return nil
                    }

                    return OutputCard(
                        kanji: detail.kanji,
                        meanings: detail.meanings,
                        onyomi: detail.onReadings,
                        kunyomi: detail.kunReadings,
                        examples: [],
                        source: OutputSource(name: "kanjiapi.dev + KanjiVG", file: fileName, license: "KanjiVG: Creative Commons Attribution-Share Alike 3.0"),
                        strokes: strokes,
                        grade: detail.grade,
                        jlpt: detail.jlpt,
                        translationState: nil
                    )
                } catch {
                    return nil
                }
            }
            return
        }
    }

    for _ in 0..<maxConcurrentRequests {
        enqueueNext()
    }

    var completed = cardsByKanji.count
    for try await card in group {
        if let card {
            cardsByKanji[card.kanji] = card
        }

        completed += 1
        if completed % 100 == 0 {
            let ordered = allKanji.compactMap { cardsByKanji[$0] }
            try encoder.encode(ordered).write(to: outputURL, options: .atomic)
            print("Saved \(ordered.count)/\(allKanji.count)")
        }

        enqueueNext()
    }
}

let ordered = allKanji.compactMap { cardsByKanji[$0] }
try encoder.encode(ordered).write(to: outputURL, options: .atomic)
print("Done: \(ordered.count)/\(allKanji.count) cards written to \(outputURL.path)")
