import CoreGraphics
import Foundation

enum StrokeEvaluator {
    static func evaluateCompletedStrokes(actual: [[CGPoint]], expected: [KanjiStroke]) -> [StrokeFeedback] {
        guard !actual.isEmpty else {
            return []
        }

        var feedback: [StrokeFeedback] = []
        for (index, stroke) in actual.enumerated() {
            guard index < expected.count else {
                feedback.append(
                    StrokeFeedback(
                        strokeIndex: index,
                        severity: .extra,
                        message: "Штрих \(index + 1): лишний."
                    )
                )
                continue
            }

            feedback.append(evaluateStroke(stroke, expected: expected[index], index: index))
        }

        return feedback
    }

    static func evaluate(actual: [[CGPoint]], expected: [KanjiStroke]) -> [StrokeFeedback] {
        guard !actual.isEmpty else {
            return [
                StrokeFeedback(
                    strokeIndex: nil,
                    severity: .info,
                    message: "Пока нет штрихов. Нарисуй кандзи, потом нажми «Проверить»."
                )
            ]
        }

        var feedback: [StrokeFeedback] = []
        let countSeverity: StrokeFeedbackSeverity = actual.count == expected.count ? .good : .major
        let countMessage = actual.count == expected.count
            ? "Количество штрихов похоже на правильное."
            : "Нужно \(expected.count) штриха, сейчас распознано \(actual.count)."
        feedback.append(StrokeFeedback(strokeIndex: nil, severity: countSeverity, message: countMessage))

        for (index, expectedStroke) in expected.enumerated() {
            guard index < actual.count else {
                feedback.append(
                    StrokeFeedback(
                        strokeIndex: index,
                        severity: .missing,
                        message: "Штрих \(index + 1): не найден."
                    )
                )
                continue
            }

            feedback.append(evaluateStroke(actual[index], expected: expectedStroke, index: index))
        }

        if actual.count > expected.count {
            for index in expected.count..<actual.count {
                feedback.append(
                    StrokeFeedback(
                        strokeIndex: index,
                        severity: .extra,
                        message: "Штрих \(index + 1): лишний."
                    )
                )
            }
        }

        return feedback
    }

    private static func evaluateStroke(_ points: [CGPoint], expected: KanjiStroke, index: Int) -> StrokeFeedback {
        guard let start = points.first, let end = points.last else {
            return StrokeFeedback(strokeIndex: index, severity: .missing, message: "Штрих \(index + 1): не найден.")
        }

        let forwardDistance = start.distance(to: expected.startPoint) + end.distance(to: expected.endPoint)
        let reverseDistance = start.distance(to: expected.endPoint) + end.distance(to: expected.startPoint)
        let directionOK = forwardDistance <= reverseDistance
        let shapeOK = strokeShapeLooksRight(points, axis: expected.axis)
        let placementSeverity = placementSeverity(forwardDistance)

        if directionOK && shapeOK && placementSeverity == .good {
            return StrokeFeedback(strokeIndex: index, severity: .good, message: "Штрих \(index + 1): хорошо.")
        }

        var problems: [String] = []
        if !directionOK {
            problems.append("направление обратное")
        }
        if !shapeOK {
            problems.append("форма отличается")
        }
        if placementSeverity != .good {
            problems.append(placementSeverity == .minor ? "чуть смещён" : "далеко от нужного места")
        }

        let severity: StrokeFeedbackSeverity = (!directionOK || placementSeverity == .major) ? .major : .minor
        let prefix = severity == .minor ? "слегка отличается" : "сильно отличается"
        return StrokeFeedback(
            strokeIndex: index,
            severity: severity,
            message: "Штрих \(index + 1): \(prefix) — \(problems.joined(separator: ", "))."
        )
    }

    private static func placementSeverity(_ distance: CGFloat) -> StrokeFeedbackSeverity {
        if distance < 34 {
            return .good
        }

        return distance < 54 ? .minor : .major
    }

    private static func strokeShapeLooksRight(_ points: [CGPoint], axis: StrokeAxis) -> Bool {
        let box = boundingBox(for: points)
        let width = box.width
        let height = box.height

        switch axis {
        case .horizontal:
            return width > height * 1.5
        case .vertical:
            return height > width * 1.5
        case .corner:
            return width > 18 && height > 24
        }
    }

    private static func boundingBox(for points: [CGPoint]) -> CGRect {
        guard let first = points.first else {
            return .zero
        }

        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { box, point in
            box.union(CGRect(origin: point, size: .zero))
        }
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
