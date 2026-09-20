import Foundation

nonisolated enum BuiltInCardSide: String, CaseIterable, Identifiable, Codable, Sendable {
    case front
    case back

    var id: String { rawValue }
    var title: String { self == .front ? "Лицевая сторона" : "Задняя сторона" }
}

nonisolated enum BuiltInCardField: String, Identifiable, Codable, Sendable {
    case character
    case word
    case reading
    case onyomi
    case kunyomi
    case meanings
    case strokeCount
    case strokeOrder
    case components
    case examples

    var id: String { rawValue }

    func title(for mode: PracticeMode) -> String {
        switch self {
        case .character: mode == .kana ? "Кана" : "Кандзи"
        case .word: "Слово"
        case .reading: "Чтение"
        case .onyomi: "Онъёми"
        case .kunyomi: "Кунъёми"
        case .meanings: mode == .words ? "Перевод" : "Значения"
        case .strokeCount: "Число штрихов"
        case .strokeOrder: "Порядок штрихов"
        case .components: "Состав"
        case .examples: "Примеры"
        }
    }

    static func available(for mode: PracticeMode) -> [Self] {
        switch mode {
        case .kanji: [.character, .onyomi, .kunyomi, .meanings, .strokeOrder, .examples]
        case .words: [.word, .reading, .meanings, .components, .examples]
        case .kana: [.character, .reading, .strokeCount, .strokeOrder]
        case .anki: []
        }
    }
}

nonisolated struct BuiltInCardFieldOptions: Equatable, Sendable {
    var order: [BuiltInCardField]
    var visible: Set<BuiltInCardField>

    var displayedFields: [BuiltInCardField] { order.filter(visible.contains) }

    func normalized(for mode: PracticeMode) -> Self {
        let available = BuiltInCardField.available(for: mode)
        let allowed = Set(available)
        var seen = Set<BuiltInCardField>()
        let normalizedOrder = order.filter { allowed.contains($0) && seen.insert($0).inserted }
            + available.filter { !seen.contains($0) }
        return .init(order: normalizedOrder, visible: visible.intersection(allowed))
    }
}

extension DeckOptions {
    nonisolated func builtInCardFields(for mode: PracticeMode, side: BuiltInCardSide) -> BuiltInCardFieldOptions {
        let available = BuiltInCardField.available(for: mode)
        let storedOrder = side == .front ? builtInFrontFieldOrder : builtInBackFieldOrder
        let storedVisible = side == .front ? builtInFrontVisibleFields : builtInBackVisibleFields
        if let storedOrder, let storedVisible {
            return BuiltInCardFieldOptions(order: storedOrder, visible: storedVisible).normalized(for: mode)
        }

        if side == .back {
            return .init(order: available, visible: Set(available))
        }

        let mappedOrder = frontFieldOrder.flatMap { legacyField -> [BuiltInCardField] in
            switch (mode, legacyField) {
            case (.kanji, .readings): [.onyomi, .kunyomi]
            case (.words, .readings), (.kana, .readings): [.reading]
            case (.words, .character): [.word]
            case (.kanji, .character), (.kana, .character): [.character]
            case (_, .meanings): [.meanings]
            default: []
            }
        }
        let visible = Set(mappedOrder.filter { field in
            switch field {
            case .character, .word: showsPromptCharacters
            case .reading, .onyomi, .kunyomi: showsPromptReading
            case .meanings: showsPromptMeaning
            default: false
            }
        })
        return BuiltInCardFieldOptions(order: mappedOrder, visible: visible).normalized(for: mode)
    }

    nonisolated mutating func setBuiltInCardFields(_ value: BuiltInCardFieldOptions, for mode: PracticeMode,
                                                   side: BuiltInCardSide) {
        let normalized = value.normalized(for: mode)
        if side == .front {
            builtInFrontFieldOrder = normalized.order
            builtInFrontVisibleFields = normalized.visible
            showsPromptCharacters = normalized.visible.contains(.character) || normalized.visible.contains(.word)
            showsPromptReading = !normalized.visible.isDisjoint(with: [.reading, .onyomi, .kunyomi])
            showsPromptMeaning = normalized.visible.contains(.meanings)
        } else {
            builtInBackFieldOrder = normalized.order
            builtInBackVisibleFields = normalized.visible
        }
    }
}
