import SwiftUI

enum SVGPathParser {
    static func path(from pathData: String) -> Path {
        var path = Path()
        var current = CGPoint.zero

        for segment in segments(in: pathData) {
            let values = numbers(in: segment.arguments)

            switch segment.command {
            case "M":
                for index in stride(from: 0, to: values.count - 1, by: 2) {
                    current = CGPoint(x: values[index], y: values[index + 1])
                    path.move(to: current)
                }
            case "m":
                for index in stride(from: 0, to: values.count - 1, by: 2) {
                    current = CGPoint(x: current.x + values[index], y: current.y + values[index + 1])
                    path.move(to: current)
                }
            case "L":
                for index in stride(from: 0, to: values.count - 1, by: 2) {
                    current = CGPoint(x: values[index], y: values[index + 1])
                    path.addLine(to: current)
                }
            case "l":
                for index in stride(from: 0, to: values.count - 1, by: 2) {
                    current = CGPoint(x: current.x + values[index], y: current.y + values[index + 1])
                    path.addLine(to: current)
                }
            case "C":
                for index in stride(from: 0, to: values.count - 5, by: 6) {
                    let control1 = CGPoint(x: values[index], y: values[index + 1])
                    let control2 = CGPoint(x: values[index + 2], y: values[index + 3])
                    current = CGPoint(x: values[index + 4], y: values[index + 5])
                    path.addCurve(to: current, control1: control1, control2: control2)
                }
            case "c":
                for index in stride(from: 0, to: values.count - 5, by: 6) {
                    let control1 = CGPoint(x: current.x + values[index], y: current.y + values[index + 1])
                    let control2 = CGPoint(x: current.x + values[index + 2], y: current.y + values[index + 3])
                    current = CGPoint(x: current.x + values[index + 4], y: current.y + values[index + 5])
                    path.addCurve(to: current, control1: control1, control2: control2)
                }
            default:
                break
            }
        }

        return path
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
