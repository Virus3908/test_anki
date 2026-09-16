import Foundation

protocol MeaningTranslating {
    func translateLocally(_ meanings: [String]) -> [String]
    func translate(_ meanings: [String]) async -> [String]
    func translatePreservingOrder(_ meanings: [String]) async -> [String]
}

struct SystemRussianMeaningTranslator: MeaningTranslating {
    nonisolated init() {}

    private static let systemTranslationQueue = SystemTranslationQueue()

    func translateLocally(_ meanings: [String]) -> [String] {
        Self.unique(RussianMeaningDictionary.translate(meanings))
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
            return RussianMeaningDictionary.translate(meanings)
        }

        let localTranslation = RussianMeaningDictionary.translate(meanings)
        return bestTranslation.enumerated().map { index, translatedItem in
            translatedItem.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(meanings[index].trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
                ? localTranslation[index]
                : translatedItem
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

private actor SystemTranslationQueue {
    func translate(_ meanings: [String]) async throws -> [String] {
        try await withTimeout(seconds: 8) {
            try await SystemTranslationClient.translate(meanings)
        }
    }

    private func withTimeout<Value>(seconds: UInt64, operation: @escaping () async throws -> Value) async throws -> Value {
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
