import CoreGraphics
import Foundation

enum KanaStrokePresets {
    static func strokes(for character: String) -> [KanjiStroke] {
        if let direct = directStrokes(for: character) {
            return direct
        }

        if let voiced = voicedBase[character] {
            return buildStrokes(from: baseShapes(for: voiced.base) + markShapes(voiced.mark))
        }

        if let small = smallBase[character] {
            let shapes = baseShapes(for: small).map { $0.transformed(scaleX: 0.72, scaleY: 0.72, translateX: 15, translateY: 16) }
            return buildStrokes(from: shapes)
        }

        let parts = character.map(String.init)
        guard parts.count > 1 else {
            return []
        }

        return combinedStrokes(for: parts)
    }

    private static func directStrokes(for character: String) -> [KanjiStroke]? {
        let shapes = baseShapes(for: character)
        return shapes.isEmpty ? nil : buildStrokes(from: shapes)
    }

    private static func combinedStrokes(for parts: [String]) -> [KanjiStroke] {
        let shapes = parts.enumerated().flatMap { index, part -> [KanaStrokeShape] in
            let shapes = baseShapesWithMarks(for: part)
            if index == 0 {
                return shapes.map { $0.transformed(scaleX: 0.68, scaleY: 0.68, translateX: 4, translateY: 17) }
            }

            return shapes.map { $0.transformed(scaleX: 0.48, scaleY: 0.48, translateX: 62, translateY: 38) }
        }

        return buildStrokes(from: shapes)
    }

    private static func baseShapesWithMarks(for character: String) -> [KanaStrokeShape] {
        if let voiced = voicedBase[character] {
            return baseShapes(for: voiced.base) + markShapes(voiced.mark)
        }

        if let small = smallBase[character] {
            return baseShapes(for: small)
        }

        return baseShapes(for: character)
    }

    private static func buildStrokes(from shapes: [KanaStrokeShape]) -> [KanjiStroke] {
        shapes.enumerated().compactMap { index, shape in
            guard let start = shape.points.first, let end = shape.points.last else {
                return nil
            }

            return KanjiStroke(
                order: index + 1,
                pathData: shape.pathData,
                start: [start.x, start.y],
                end: [end.x, end.y],
                axis: shape.axis
            )
        }
    }

    private static func markShapes(_ mark: KanaMark) -> [KanaStrokeShape] {
        switch mark {
        case .dakuten:
            return [
                stroke((72, 13), (79, 22)),
                stroke((88, 13), (95, 22))
            ]
        case .handakuten:
            return [stroke((82, 13), (90, 13), (94, 20), (90, 27), (82, 27), (78, 20), (82, 13))]
        }
    }

    private static func baseShapes(for character: String) -> [KanaStrokeShape] {
        hiraganaBase[character] ?? katakanaBase[character] ?? []
    }

    private static func stroke(_ points: (Double, Double)...) -> KanaStrokeShape {
        KanaStrokeShape(points: points.map { CGPoint(x: $0.0, y: $0.1) })
    }

    private static let smallBase: [String: String] = [
        "ぁ": "あ", "ぃ": "い", "ぅ": "う", "ぇ": "え", "ぉ": "お",
        "ゃ": "や", "ゅ": "ゆ", "ょ": "よ", "っ": "つ", "ゎ": "わ",
        "ァ": "ア", "ィ": "イ", "ゥ": "ウ", "ェ": "エ", "ォ": "オ",
        "ャ": "ヤ", "ュ": "ユ", "ョ": "ヨ", "ッ": "ツ", "ヮ": "ワ"
    ]

    private static let voicedBase: [String: (base: String, mark: KanaMark)] = [
        "が": ("か", .dakuten), "ぎ": ("き", .dakuten), "ぐ": ("く", .dakuten), "げ": ("け", .dakuten), "ご": ("こ", .dakuten),
        "ざ": ("さ", .dakuten), "じ": ("し", .dakuten), "ず": ("す", .dakuten), "ぜ": ("せ", .dakuten), "ぞ": ("そ", .dakuten),
        "だ": ("た", .dakuten), "ぢ": ("ち", .dakuten), "づ": ("つ", .dakuten), "で": ("て", .dakuten), "ど": ("と", .dakuten),
        "ば": ("は", .dakuten), "び": ("ひ", .dakuten), "ぶ": ("ふ", .dakuten), "べ": ("へ", .dakuten), "ぼ": ("ほ", .dakuten),
        "ぱ": ("は", .handakuten), "ぴ": ("ひ", .handakuten), "ぷ": ("ふ", .handakuten), "ぺ": ("へ", .handakuten), "ぽ": ("ほ", .handakuten),
        "ガ": ("カ", .dakuten), "ギ": ("キ", .dakuten), "グ": ("ク", .dakuten), "ゲ": ("ケ", .dakuten), "ゴ": ("コ", .dakuten),
        "ザ": ("サ", .dakuten), "ジ": ("シ", .dakuten), "ズ": ("ス", .dakuten), "ゼ": ("セ", .dakuten), "ゾ": ("ソ", .dakuten),
        "ダ": ("タ", .dakuten), "ヂ": ("チ", .dakuten), "ヅ": ("ツ", .dakuten), "デ": ("テ", .dakuten), "ド": ("ト", .dakuten),
        "バ": ("ハ", .dakuten), "ビ": ("ヒ", .dakuten), "ブ": ("フ", .dakuten), "ベ": ("ヘ", .dakuten), "ボ": ("ホ", .dakuten),
        "パ": ("ハ", .handakuten), "ピ": ("ヒ", .handakuten), "プ": ("フ", .handakuten), "ペ": ("ヘ", .handakuten), "ポ": ("ホ", .handakuten),
        "ヴ": ("ウ", .dakuten)
    ]

    private static let hiraganaBase: [String: [KanaStrokeShape]] = [
        "あ": [stroke((30, 29), (77, 25)), stroke((53, 16), (50, 81)), stroke((32, 56), (53, 43), (76, 53), (69, 81), (38, 82))],
        "い": [stroke((35, 28), (32, 55), (40, 75)), stroke((72, 33), (81, 56), (76, 75))],
        "う": [stroke((45, 25), (66, 31)), stroke((31, 49), (61, 45), (75, 57), (59, 82))],
        "え": [stroke((47, 24), (66, 27)), stroke((32, 47), (66, 43), (42, 66), (55, 60), (70, 80), (86, 70))],
        "お": [stroke((29, 33), (79, 29)), stroke((52, 18), (49, 82)), stroke((32, 64), (52, 49), (76, 56), (72, 78)), stroke((77, 37), (91, 47))],
        "か": [stroke((27, 41), (79, 35)), stroke((58, 20), (45, 84)), stroke((75, 43), (87, 60), (81, 78))],
        "き": [stroke((31, 26), (76, 20)), stroke((28, 42), (80, 35)), stroke((49, 17), (66, 66)), stroke((40, 72), (56, 83), (78, 75))],
        "く": [stroke((70, 22), (38, 52), (70, 84))],
        "け": [stroke((31, 25), (27, 58), (34, 81)), stroke((50, 36), (86, 31)), stroke((70, 20), (69, 58), (55, 84))],
        "こ": [stroke((34, 34), (76, 31)), stroke((32, 70), (77, 72))],
        "さ": [stroke((32, 28), (78, 23)), stroke((51, 16), (68, 58)), stroke((35, 74), (57, 84), (80, 74))],
        "し": [stroke((42, 24), (38, 58), (47, 78), (75, 69))],
        "す": [stroke((25, 36), (86, 33)), stroke((58, 18), (58, 55), (49, 70), (63, 78), (72, 62), (58, 51))],
        "せ": [stroke((25, 45), (86, 37)), stroke((46, 27), (45, 71)), stroke((71, 23), (67, 54)), stroke((37, 65), (49, 78), (79, 75))],
        "そ": [stroke((34, 28), (73, 27), (45, 49), (78, 48)), stroke((72, 48), (49, 58), (38, 75), (67, 83))],
        "た": [stroke((31, 34), (80, 28)), stroke((50, 17), (35, 84)), stroke((59, 47), (83, 43)), stroke((59, 72), (84, 75))],
        "ち": [stroke((29, 34), (79, 28)), stroke((52, 18), (43, 59), (60, 48), (80, 55), (70, 80), (44, 82))],
        "つ": [stroke((28, 49), (54, 40), (78, 48), (74, 69), (51, 80))],
        "て": [stroke((29, 35), (81, 31), (55, 46), (45, 65), (63, 82))],
        "と": [stroke((47, 22), (55, 56)), stroke((78, 31), (43, 57), (38, 75), (76, 78))],
        "な": [stroke((28, 34), (80, 29)), stroke((49, 18), (34, 68)), stroke((70, 37), (88, 48)), stroke((58, 58), (55, 78), (75, 82), (77, 60))],
        "に": [stroke((32, 24), (29, 58), (34, 82)), stroke((54, 39), (83, 36)), stroke((52, 72), (84, 74))],
        "ぬ": [stroke((30, 32), (48, 67), (39, 84)), stroke((71, 24), (59, 73)), stroke((35, 56), (58, 39), (82, 54), (72, 81), (49, 75))],
        "ね": [stroke((36, 24), (34, 84)), stroke((24, 48), (48, 35), (35, 60)), stroke((49, 47), (69, 31), (83, 46), (73, 76)), stroke((63, 74), (85, 83))],
        "の": [stroke((64, 27), (39, 43), (35, 68), (52, 80), (76, 68), (79, 42), (64, 27))],
        "は": [stroke((31, 24), (28, 59), (35, 83)), stroke((51, 41), (85, 37)), stroke((69, 23), (69, 75)), stroke((55, 69), (72, 82), (84, 67))],
        "ひ": [stroke((31, 36), (44, 75), (69, 78), (82, 42)), stroke((74, 28), (88, 42))],
        "ふ": [stroke((49, 23), (66, 34)), stroke((40, 49), (27, 69)), stroke((61, 47), (54, 82)), stroke((77, 51), (90, 69))],
        "へ": [stroke((26, 64), (50, 41), (84, 70))],
        "ほ": [stroke((30, 24), (27, 59), (35, 82)), stroke((51, 32), (85, 28)), stroke((51, 51), (85, 48)), stroke((70, 19), (70, 76)), stroke((55, 70), (72, 83), (86, 67))],
        "ま": [stroke((32, 29), (79, 25)), stroke((31, 47), (82, 43)), stroke((58, 17), (58, 76)), stroke((41, 67), (58, 83), (79, 68))],
        "み": [stroke((35, 31), (62, 30), (46, 63), (28, 60), (38, 79), (58, 63)), stroke((72, 38), (86, 56)), stroke((67, 57), (86, 73))],
        "む": [stroke((31, 36), (76, 31)), stroke((50, 18), (47, 72)), stroke((39, 64), (53, 82), (74, 72)), stroke((74, 42), (90, 56))],
        "め": [stroke((30, 32), (49, 70), (38, 84)), stroke((70, 24), (58, 75)), stroke((39, 58), (60, 41), (83, 55), (73, 81))],
        "も": [stroke((53, 18), (47, 79), (67, 83)), stroke((31, 37), (76, 32)), stroke((29, 55), (72, 52))],
        "や": [stroke((29, 47), (84, 34)), stroke((45, 28), (57, 86)), stroke((66, 23), (82, 43), (69, 58))],
        "ゆ": [stroke((34, 36), (31, 68), (50, 76), (75, 64), (78, 39), (60, 30), (38, 45)), stroke((58, 18), (55, 88))],
        "よ": [stroke((58, 18), (57, 73)), stroke((59, 39), (84, 35)), stroke((42, 68), (60, 84), (82, 69))],
        "ら": [stroke((46, 24), (66, 30)), stroke((37, 41), (32, 64), (56, 51), (79, 59), (66, 82), (43, 83))],
        "り": [stroke((38, 24), (38, 61)), stroke((72, 20), (72, 54), (58, 83))],
        "る": [stroke((39, 31), (72, 27), (48, 51), (68, 48), (82, 64), (68, 82), (49, 75), (61, 64))],
        "れ": [stroke((36, 24), (33, 84)), stroke((24, 49), (48, 35), (36, 61)), stroke((48, 48), (69, 31), (81, 42), (69, 77), (88, 67))],
        "ろ": [stroke((38, 31), (72, 27), (49, 51), (70, 49), (82, 64), (66, 82), (42, 78))],
        "わ": [stroke((36, 24), (33, 84)), stroke((24, 49), (49, 35), (36, 60)), stroke((49, 47), (73, 35), (84, 56), (70, 79))],
        "を": [stroke((30, 31), (76, 27)), stroke((51, 18), (35, 72)), stroke((43, 49), (68, 42), (79, 55), (57, 72)), stroke((79, 39), (42, 61), (38, 78), (80, 78))],
        "ん": [stroke((34, 78), (50, 46), (63, 25), (55, 68), (73, 79), (88, 60))]
    ]

    private static let katakanaBase: [String: [KanaStrokeShape]] = [
        "ア": [stroke((26, 30), (86, 30), (62, 53)), stroke((55, 42), (45, 83))],
        "イ": [stroke((80, 21), (30, 58)), stroke((57, 43), (57, 84))],
        "ウ": [stroke((54, 19), (54, 34)), stroke((28, 34), (82, 34), (73, 76), (45, 86))],
        "エ": [stroke((34, 34), (76, 34)), stroke((55, 34), (55, 72)), stroke((28, 74), (84, 74))],
        "オ": [stroke((29, 38), (85, 34)), stroke((63, 20), (63, 84)), stroke((60, 42), (33, 74))],
        "カ": [stroke((28, 41), (83, 36)), stroke((58, 20), (46, 82)), stroke((65, 39), (80, 43), (73, 80))],
        "キ": [stroke((33, 29), (78, 23)), stroke((28, 48), (84, 40)), stroke((53, 18), (67, 85))],
        "ク": [stroke((51, 20), (35, 49)), stroke((49, 35), (82, 35), (68, 75), (43, 86))],
        "ケ": [stroke((41, 20), (28, 49)), stroke((39, 38), (86, 35)), stroke((64, 37), (53, 84))],
        "コ": [stroke((32, 35), (79, 35), (79, 73), (29, 73))],
        "サ": [stroke((29, 38), (86, 34)), stroke((47, 22), (47, 55)), stroke((68, 19), (67, 54), (55, 82))],
        "シ": [stroke((31, 29), (48, 36)), stroke((28, 50), (45, 56)), stroke((80, 34), (60, 67), (34, 82))],
        "ス": [stroke((34, 32), (77, 30), (57, 59), (30, 82)), stroke((58, 58), (83, 82))],
        "セ": [stroke((27, 49), (86, 39)), stroke((49, 21), (48, 72)), stroke((72, 41), (59, 60)), stroke((40, 68), (53, 78), (81, 76))],
        "ソ": [stroke((34, 34), (47, 60)), stroke((79, 27), (65, 67), (42, 85))],
        "タ": [stroke((50, 21), (33, 50)), stroke((47, 37), (82, 38), (69, 78), (42, 87)), stroke((47, 54), (70, 68))],
        "チ": [stroke((39, 28), (73, 22)), stroke((28, 48), (86, 43)), stroke((56, 44), (48, 83))],
        "ツ": [stroke((31, 34), (42, 57)), stroke((52, 29), (61, 54)), stroke((83, 28), (67, 69), (40, 86))],
        "テ": [stroke((39, 29), (74, 25)), stroke((28, 47), (86, 42)), stroke((57, 44), (48, 84))],
        "ト": [stroke((44, 20), (44, 84)), stroke((47, 40), (83, 57))],
        "ナ": [stroke((28, 42), (86, 38)), stroke((57, 19), (51, 58), (35, 84))],
        "ニ": [stroke((34, 37), (77, 37)), stroke((29, 72), (83, 72))],
        "ヌ": [stroke((35, 31), (80, 30), (61, 60), (31, 83)), stroke((40, 45), (82, 82))],
        "ネ": [stroke((48, 22), (65, 30)), stroke((29, 43), (78, 41), (31, 75)), stroke((55, 55), (55, 84)), stroke((58, 56), (84, 76))],
        "ノ": [stroke((75, 24), (60, 64), (37, 84))],
        "ハ": [stroke((45, 29), (30, 79)), stroke((65, 29), (86, 78))],
        "ヒ": [stroke((42, 21), (42, 76)), stroke((43, 50), (78, 37)), stroke((42, 75), (78, 75))],
        "フ": [stroke((31, 34), (81, 34), (67, 68), (42, 85))],
        "ヘ": [stroke((27, 64), (50, 42), (84, 70))],
        "ホ": [stroke((29, 39), (84, 35)), stroke((58, 20), (58, 84)), stroke((47, 52), (29, 76)), stroke((69, 52), (88, 75))],
        "マ": [stroke((27, 33), (86, 33), (59, 70)), stroke((44, 55), (65, 83))],
        "ミ": [stroke((38, 29), (76, 36)), stroke((34, 48), (72, 56)), stroke((29, 69), (80, 80))],
        "ム": [stroke((62, 22), (37, 76), (80, 70)), stroke((72, 56), (89, 80))],
        "メ": [stroke((75, 27), (32, 82)), stroke((38, 36), (83, 76))],
        "モ": [stroke((34, 29), (79, 26)), stroke((29, 49), (84, 45)), stroke((55, 27), (52, 72), (68, 82))],
        "ヤ": [stroke((28, 45), (85, 35)), stroke((45, 28), (60, 86)), stroke((67, 30), (80, 49), (66, 62))],
        "ユ": [stroke((38, 37), (75, 37), (75, 73)), stroke((29, 74), (85, 74))],
        "ヨ": [stroke((35, 31), (77, 31), (77, 72), (32, 72)), stroke((37, 51), (76, 51))],
        "ラ": [stroke((39, 28), (74, 25)), stroke((29, 45), (82, 43), (68, 74), (42, 86))],
        "リ": [stroke((40, 25), (40, 61)), stroke((73, 22), (72, 57), (58, 84))],
        "ル": [stroke((45, 27), (39, 64), (27, 83)), stroke((63, 23), (63, 78), (86, 58))],
        "レ": [stroke((43, 24), (43, 78), (82, 55))],
        "ロ": [stroke((34, 34), (78, 34), (78, 75), (34, 75), (34, 34))],
        "ワ": [stroke((28, 34), (82, 34), (73, 70), (48, 86))],
        "ヲ": [stroke((36, 28), (78, 28)), stroke((29, 47), (84, 44), (67, 75), (42, 87))],
        "ン": [stroke((33, 34), (52, 51)), stroke((83, 31), (62, 67), (35, 84))]
    ]
}

private enum KanaMark {
    case dakuten
    case handakuten
}

private struct KanaStrokeShape {
    let points: [CGPoint]

    var pathData: String {
        guard let first = points.first else {
            return ""
        }

        let rest = points.dropFirst().map { point in
            "L \(format(point.x)) \(format(point.y))"
        }
        return (["M \(format(first.x)) \(format(first.y))"] + rest).joined(separator: " ")
    }

    var axis: StrokeAxis {
        let box = boundingBox
        if box.width > box.height * 1.5 {
            return .horizontal
        }
        if box.height > box.width * 1.5 {
            return .vertical
        }
        return .corner
    }

    func transformed(scaleX: CGFloat, scaleY: CGFloat, translateX: CGFloat, translateY: CGFloat) -> KanaStrokeShape {
        KanaStrokeShape(points: points.map { point in
            CGPoint(x: point.x * scaleX + translateX, y: point.y * scaleY + translateY)
        })
    }

    private var boundingBox: CGRect {
        guard let first = points.first else {
            return .zero
        }

        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { box, point in
            box.union(CGRect(origin: point, size: .zero))
        }
    }

    private func format(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
    }
}

