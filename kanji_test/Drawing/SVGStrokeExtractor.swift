import Foundation
import CoreGraphics

nonisolated enum SVGStrokeExtractor {
    static func strokes(from svgText: String) -> [KanjiStroke] {
        strokes(fromPathData: pathDataValues(in: svgText))
    }

    static func strokes(fromPathData pathDataValues: [String]) -> [KanjiStroke] {
        pathDataValues.enumerated().compactMap { index, pathData in
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
