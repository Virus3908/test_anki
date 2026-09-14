import Foundation
import CoreGraphics

struct KanjiSource: Codable, Sendable {
    let name: String
    let file: String
    let license: String
}

struct KanjiStroke: Codable, Identifiable, Sendable {
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

enum StrokeAxis: String, Codable, Sendable {
    case horizontal
    case vertical
    case corner
}
