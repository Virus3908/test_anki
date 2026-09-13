import Foundation
import CoreGraphics

struct KanjiCard: Codable, Identifiable {
    var id: String { kanji }

    let kanji: String
    let meanings: [String]
    let onyomi: [String]
    let kunyomi: [String]
    let examples: [KanjiExample]
    let source: KanjiSource
    let strokes: [KanjiStroke]
}

struct KanjiExample: Codable, Identifiable {
    var id: String { "\(word)-\(reading)" }

    let word: String
    let reading: String
    let meaning: String
}

struct KanjiSource: Codable {
    let name: String
    let file: String
    let license: String
}

struct KanjiStroke: Codable, Identifiable {
    var id: Int { order }

    let order: Int
    let pathData: String
    let start: [Double]
    let end: [Double]
    let axis: StrokeAxis

    enum CodingKeys: String, CodingKey {
        case order
        case pathData = "path"
        case start
        case end
        case axis
    }

    var startPoint: CGPoint {
        CGPoint(x: start[0], y: start[1])
    }

    var endPoint: CGPoint {
        CGPoint(x: end[0], y: end[1])
    }
}

enum StrokeAxis: String, Codable {
    case horizontal
    case vertical
    case corner
}

enum KanjiDeck: String, CaseIterable, Identifiable {
    case grade1
    case jlpt5
    case jlpt4
    case jlpt3
    case jlpt2
    case jlpt1

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grade1:
            return "Grade 1"
        case .jlpt5:
            return "JLPT N5"
        case .jlpt4:
            return "JLPT N4"
        case .jlpt3:
            return "JLPT N3"
        case .jlpt2:
            return "JLPT N2"
        case .jlpt1:
            return "JLPT N1"
        }
    }

    var endpointPath: String {
        switch self {
        case .grade1:
            return "grade-1"
        case .jlpt5:
            return "jlpt-5"
        case .jlpt4:
            return "jlpt-4"
        case .jlpt3:
            return "jlpt-3"
        case .jlpt2:
            return "jlpt-2"
        case .jlpt1:
            return "jlpt-1"
        }
    }
}

enum KanjiDataLoader {
    static func loadLocalCards() -> [KanjiCard] {
        guard let url = Bundle.main.url(forResource: "kanji-data", withExtension: "json") else {
            assertionFailure("kanji-data.json is missing from the app bundle.")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([KanjiCard].self, from: data)
        } catch {
            assertionFailure("Failed to decode kanji-data.json: \(error)")
            return []
        }
    }

    static func loadCards(deck: KanjiDeck = .jlpt5) async -> [KanjiCard] {
        do {
            let remoteCards = try await RemoteKanjiProvider.loadCards(deck: deck, limit: 20)
            if !remoteCards.isEmpty {
                return remoteCards
            }
        } catch {
            assertionFailure("Failed to load remote kanji data: \(error)")
        }

        return loadLocalCards()
    }
}

private enum RemoteKanjiProvider {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        return URLSession(configuration: configuration)
    }()

    static func loadCards(deck: KanjiDeck, limit: Int) async throws -> [KanjiCard] {
        let listURL = URL(string: "https://kanjiapi.dev/v1/kanji/\(deck.endpointPath)")!
        let (listData, _) = try await session.data(from: listURL)
        let kanjiList = try JSONDecoder().decode([String].self, from: listData).shuffled()
        let candidates = Array(kanjiList.prefix(limit * 3))
        var cards: [KanjiCard] = []

        await withTaskGroup(of: KanjiCard?.self) { group in
            for kanji in candidates {
                group.addTask {
                    try? await loadCard(for: kanji)
                }
            }

            for await card in group {
                guard let card else {
                    continue
                }

                cards.append(card)

                if cards.count == limit {
                    group.cancelAll()
                    break
                }
            }
        }

        return cards
    }

    private static func loadCard(for kanji: String) async throws -> KanjiCard {
        let detailURL = URL(string: "https://kanjiapi.dev/v1/kanji/\(kanji)")!
        let svgURL = URL(string: "https://raw.githubusercontent.com/KanjiVG/kanjivg/master/kanji/\(svgFileName(for: kanji))")!

        async let detailData = session.data(from: detailURL).0
        async let svgData = session.data(from: svgURL).0

        let detail = try JSONDecoder().decode(RemoteKanjiDetail.self, from: try await detailData)
        let svgText = String(decoding: try await svgData, as: UTF8.self)
        let strokes = SVGStrokeExtractor.strokes(from: svgText)

        guard !strokes.isEmpty else {
            throw RemoteKanjiError.missingStrokes
        }

        let translatedMeanings = await RussianMeaningTranslator.translate(detail.meanings, session: session)
        let allReadings = (detail.kunReadings + detail.onReadings).joined(separator: ", ")

        return KanjiCard(
            kanji: detail.kanji,
            meanings: translatedMeanings,
            onyomi: detail.onReadings,
            kunyomi: detail.kunReadings,
            examples: [
                KanjiExample(
                    word: detail.kanji,
                    reading: allReadings,
                    meaning: translatedMeanings.joined(separator: ", ")
                )
            ],
            source: KanjiSource(
                name: "kanjiapi.dev + KanjiVG",
                file: svgFileName(for: kanji),
                license: "KanjiVG: Creative Commons Attribution-Share Alike 3.0"
            ),
            strokes: strokes
        )
    }

    private static func svgFileName(for kanji: String) -> String {
        guard let scalar = kanji.unicodeScalars.first else {
            return "00000.svg"
        }

        return String(format: "%05x.svg", scalar.value)
    }
}

private struct RemoteKanjiDetail: Decodable {
    let kanji: String
    let meanings: [String]
    let onReadings: [String]
    let kunReadings: [String]

    enum CodingKeys: String, CodingKey {
        case kanji
        case meanings
        case onReadings = "on_readings"
        case kunReadings = "kun_readings"
    }
}

private enum RemoteKanjiError: Error {
    case missingStrokes
}

private enum RussianMeaningTranslator {
    private static let translations: [String: String] = [
        "above": "верх",
        "after": "после",
        "again": "снова",
        "air": "воздух",
        "animal": "животное",
        "art": "искусство",
        "back": "задняя сторона",
        "below": "ниже",
        "big": "большой",
        "birth": "рождение",
        "blue": "синий",
        "book": "книга",
        "child": "ребенок",
        "counter for long cylindrical things": "счетный суффикс для длинных цилиндрических предметов",
        "correct": "правильный",
        "day": "день",
        "decoration": "украшение",
        "descend": "спускаться",
        "down": "низ",
        "early": "ранний",
        "ear": "ухо",
        "eight": "восемь",
        "enter": "входить",
        "eye": "глаз",
        "fast": "быстрый",
        "female": "женщина",
        "fire": "огонь",
        "five": "пять",
        "figures": "символы",
        "flower": "цветок",
        "forest": "лес",
        "four": "четыре",
        "genuine": "настоящий",
        "give": "давать",
        "gold": "золото",
        "grass": "трава",
        "hand": "рука",
        "heaven": "небо",
        "hundred": "сто",
        "inferior": "низший",
        "inside": "внутри",
        "insert": "вставлять",
        "insect": "насекомое",
        "king": "король",
        "large": "большой",
        "left": "левый",
        "life": "жизнь",
        "literary radical (no. 67)": "литературный ключ N67",
        "literature": "литература",
        "little": "маленький",
        "low": "низкий",
        "magnate": "влиятельный человек",
        "main": "основной",
        "man": "мужчина",
        "moon": "луна",
        "mountain": "гора",
        "mouth": "рот",
        "name": "имя",
        "nine": "девять",
        "one": "один",
        "origin": "происхождение",
        "person": "человек",
        "plan": "план",
        "present": "настоящее время",
        "rain": "дождь",
        "red": "красный",
        "right": "правый",
        "real": "реальный",
        "river": "река",
        "rule": "правление",
        "school": "школа",
        "sentence": "предложение",
        "style": "стиль",
        "seven": "семь",
        "six": "шесть",
        "small": "маленький",
        "sound": "звук",
        "stone": "камень",
        "sun": "солнце",
        "ten": "десять",
        "three": "три",
        "tree": "дерево",
        "true": "истинный",
        "two": "два",
        "up": "верх",
        "village": "деревня",
        "water": "вода",
        "white": "белый",
        "year": "год"
    ]

    static func translate(_ meanings: [String], session: URLSession) async -> [String] {
        if let apiTranslation = try? await translateWithAPI(meanings, session: session) {
            return unique(apiTranslation)
        }

        return unique(dictionaryTranslation(for: meanings))
    }

    private static func translateWithAPI(_ meanings: [String], session: URLSession) async throws -> [String] {
        let sourceText = meanings.joined(separator: "\n")
        guard !sourceText.isEmpty else {
            return []
        }

        var components = URLComponents(string: "https://api.mymemory.translated.net/get")!
        components.queryItems = [
            URLQueryItem(name: "q", value: sourceText),
            URLQueryItem(name: "langpair", value: "en|ru")
        ]

        guard let url = components.url else {
            return []
        }

        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(MyMemoryResponse.self, from: data)
        let translated = response.responseData.translatedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard translated.count == meanings.count else {
            return dictionaryTranslation(for: meanings)
        }

        return translated.enumerated().map { index, value in
            value.caseInsensitiveCompare(meanings[index]) == .orderedSame
                ? dictionaryTranslation(for: [meanings[index]]).first ?? value
                : value
        }
    }

    private static func dictionaryTranslation(for meanings: [String]) -> [String] {
        meanings.map { meaning in
            translations[meaning.lowercased()] ?? meaning
        }
    }

    private static func unique(_ meanings: [String]) -> [String] {
        Array(NSOrderedSet(array: meanings)).compactMap { $0 as? String }
    }
}

private struct MyMemoryResponse: Decodable {
    let responseData: ResponseData

    struct ResponseData: Decodable {
        let translatedText: String
    }
}

private enum SVGStrokeExtractor {
    static func strokes(from svgText: String) -> [KanjiStroke] {
        pathDataValues(in: svgText).enumerated().compactMap { index, pathData in
            guard let summary = summarize(pathData: pathData) else {
                return nil
            }

            return KanjiStroke(
                order: index + 1,
                pathData: pathData,
                start: [summary.start.x, summary.start.y],
                end: [summary.end.x, summary.end.y],
                axis: summary.axis
            )
        }
    }

    private static func pathDataValues(in svgText: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"<path[^>]*\sd=\"([^\"]+)\""#) else {
            return []
        }

        let range = NSRange(svgText.startIndex..<svgText.endIndex, in: svgText)
        return regex.matches(in: svgText, range: range).compactMap { match in
            guard let matchRange = Range(match.range(at: 1), in: svgText) else {
                return nil
            }

            return String(svgText[matchRange])
        }
    }

    private static func summarize(pathData: String) -> (start: CGPoint, end: CGPoint, axis: StrokeAxis)? {
        let points = points(in: pathData)
        guard let start = points.first, let end = points.last else {
            return nil
        }

        let box = points.dropFirst().reduce(CGRect(origin: start, size: .zero)) { box, point in
            box.union(CGRect(origin: point, size: .zero))
        }

        let axis: StrokeAxis
        if box.width > box.height * 1.5 {
            axis = .horizontal
        } else if box.height > box.width * 1.5 {
            axis = .vertical
        } else {
            axis = .corner
        }

        return (start, end, axis)
    }

    private static func points(in pathData: String) -> [CGPoint] {
        var points: [CGPoint] = []
        var current = CGPoint.zero

        for segment in segments(in: pathData) {
            let values = numbers(in: segment.arguments)

            switch segment.command {
            case "M", "L":
                for index in stride(from: 0, to: values.count - 1, by: 2) {
                    current = CGPoint(x: values[index], y: values[index + 1])
                    points.append(current)
                }
            case "m", "l":
                for index in stride(from: 0, to: values.count - 1, by: 2) {
                    current = CGPoint(x: current.x + values[index], y: current.y + values[index + 1])
                    points.append(current)
                }
            case "C":
                for index in stride(from: 0, to: values.count - 5, by: 6) {
                    points.append(CGPoint(x: values[index], y: values[index + 1]))
                    points.append(CGPoint(x: values[index + 2], y: values[index + 3]))
                    current = CGPoint(x: values[index + 4], y: values[index + 5])
                    points.append(current)
                }
            case "c":
                for index in stride(from: 0, to: values.count - 5, by: 6) {
                    points.append(CGPoint(x: current.x + values[index], y: current.y + values[index + 1]))
                    points.append(CGPoint(x: current.x + values[index + 2], y: current.y + values[index + 3]))
                    current = CGPoint(x: current.x + values[index + 4], y: current.y + values[index + 5])
                    points.append(current)
                }
            default:
                continue
            }
        }

        return points
    }

    private static func segments(in pathData: String) -> [(command: String, arguments: String)] {
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

    private static func numbers(in text: String) -> [Double] {
        var values: [Double] = []
        var token = ""
        var previous: Character?

        for character in text {
            let startsSignedNumber = (character == "-" || character == "+") && previous != nil && previous != "e" && previous != "E"

            if character == "," || character.isWhitespace || startsSignedNumber {
                appendToken(token, to: &values)
                token = startsSignedNumber ? String(character) : ""
            } else {
                token.append(character)
            }

            previous = character
        }

        appendToken(token, to: &values)
        return values
    }

    private static func appendToken(_ token: String, to values: inout [Double]) {
        guard !token.isEmpty, let value = Double(token) else {
            return
        }

        values.append(value)
    }
}
