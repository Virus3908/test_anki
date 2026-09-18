import Foundation
import Observation

nonisolated struct AnkiFieldDisplayOptions: Codable, Equatable, Sendable {
    var titleOrdinal: Int
    var frontOrder: [Int]
    var backOrder: [Int]
    var frontVisible: Set<Int>
    var backVisible: Set<Int>

    static func defaults(fieldCount: Int) -> Self {
        let ordinals = Array(0..<fieldCount)
        let back = fieldCount > 1 ? Array(1..<fieldCount) : ordinals
        return .init(titleOrdinal: 0, frontOrder: ordinals, backOrder: back,
                     frontVisible: fieldCount > 0 ? [0] : [], backVisible: Set(back))
    }

    func normalized(fieldCount: Int) -> Self {
        let all = Set(0..<fieldCount)
        func order(_ value: [Int]) -> [Int] {
            var seen = Set<Int>()
            return value.filter { all.contains($0) && seen.insert($0).inserted } + (0..<fieldCount).filter { !value.contains($0) }
        }
        var copy = self
        copy.titleOrdinal = all.contains(titleOrdinal) ? titleOrdinal : 0
        copy.frontOrder = order(frontOrder)
        copy.backOrder = order(backOrder)
        copy.frontVisible = frontVisible.intersection(all)
        copy.backVisible = backVisible.intersection(all)
        return copy
    }
}

@MainActor @Observable
final class AnkiFieldDisplayPreferences {
    static let shared = AnkiFieldDisplayPreferences()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "ankiFieldDisplayPreferences"
    private var values: [String: AnkiFieldDisplayOptions]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: AnkiFieldDisplayOptions].self, from: data) {
            values = decoded
        } else { values = [:] }
    }

    func options(for key: String, fieldCount: Int) -> AnkiFieldDisplayOptions {
        (values[key] ?? .defaults(fieldCount: fieldCount)).normalized(fieldCount: fieldCount)
    }

    func hasCustomOptions(for key: String) -> Bool { values[key] != nil }

    func update(_ options: AnkiFieldDisplayOptions, for key: String, fieldCount: Int) {
        values[key] = options.normalized(fieldCount: fieldCount)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(values) else { return }
        defaults.set(data, forKey: key)
    }
}
