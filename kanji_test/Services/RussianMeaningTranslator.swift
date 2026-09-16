import Foundation
import Translation

protocol MeaningTranslating {
    func translateLocally(_ meanings: [String]) -> [String]
    func translate(_ meanings: [String]) async -> [String]
    func translatePreservingOrder(_ meanings: [String]) async -> [String]
}

struct SystemRussianMeaningTranslator: MeaningTranslating {
    nonisolated init() {}

    private actor SystemTranslationQueue {
        func translate(_ meanings: [String]) async throws -> [String] {
            try await SystemRussianMeaningTranslator.withTimeout(seconds: 8) {
                try await SystemRussianMeaningTranslator.translateWithSystem(meanings)
            }
        }
    }

    private static let systemTranslationQueue = SystemTranslationQueue()
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

    func translateLocally(_ meanings: [String]) -> [String] {
        Self.unique(Self.dictionaryTranslation(for: meanings))
    }

    func translate(_ meanings: [String]) async -> [String] {
        Self.unique(await translatePreservingOrder(meanings))
    }

    func translatePreservingOrder(_ meanings: [String]) async -> [String] {
        var bestTranslation: [String]?

        for _ in 0..<3 {
            guard let systemTranslation = try? await Self.systemTranslationQueue.translate(meanings),
                  !systemTranslation.isEmpty else {
                continue
            }

            bestTranslation = systemTranslation
            if !Self.hasUntranslatedItems(systemTranslation, comparedTo: meanings) {
                return systemTranslation
            }
        }

        guard let bestTranslation, bestTranslation.count == meanings.count else {
            return Self.dictionaryTranslation(for: meanings)
        }

        let localTranslation = Self.dictionaryTranslation(for: meanings)
        return bestTranslation.enumerated().map { index, translatedItem in
            translatedItem.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(meanings[index].trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
                ? localTranslation[index]
                : translatedItem
        }
    }

    private static func withTimeout<Value>(seconds: UInt64, operation: @escaping () async throws -> Value) async throws -> Value {
        try await withThrowingTaskGroup(of: Value.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw URLError(.timedOut)
            }

            guard let value = try await group.next() else {
                throw URLError(.timedOut)
            }

            group.cancelAll()
            return value
        }
    }

    private static func translateWithSystem(_ meanings: [String]) async throws -> [String] {
        guard !meanings.isEmpty else {
            return []
        }

        let session = TranslationSession(
            installedSource: Locale.Language(identifier: "en"),
            target: Locale.Language(identifier: "ru")
        )
        let requests = meanings.map { TranslationSession.Request(sourceText: $0) }
        let responses = try await session.translations(from: requests)
        let translated = responses.map { $0.targetText.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard translated.count == meanings.count else {
            return dictionaryTranslation(for: meanings)
        }

        return translated.enumerated().map { index, value in
            value.isEmpty || value.caseInsensitiveCompare(meanings[index]) == .orderedSame
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

    private static func hasUntranslatedItems(_ translated: [String], comparedTo source: [String]) -> Bool {
        guard translated.count == source.count else {
            return true
        }

        return zip(translated, source).contains { translatedItem, sourceItem in
            translatedItem.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(sourceItem.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }
    }
}

enum RussianMeaningTranslator {
    private static let translator = SystemRussianMeaningTranslator()

    static func translateLocally(_ meanings: [String]) -> [String] {
        translator.translateLocally(meanings)
    }

    static func translate(_ meanings: [String]) async -> [String] {
        await translator.translate(meanings)
    }

    static func translatePreservingOrder(_ meanings: [String]) async -> [String] {
        await translator.translatePreservingOrder(meanings)
    }
}
