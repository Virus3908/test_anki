import Foundation

protocol MeaningTranslating {
    func translateLocally(_ meanings: [String]) -> [String]
    func translate(_ meanings: [String]) async -> [String]
    func translatePreservingOrder(_ meanings: [String]) async -> [String]
}

struct SystemRussianMeaningTranslator: MeaningTranslating {
    nonisolated init() {}

    private static let systemTranslationQueue = PriorityTranslationQueue()

    func translateLocally(_ meanings: [String]) -> [String] {
        Self.unique(RussianMeaningDictionary.translate(meanings))
    }

    func translate(_ meanings: [String]) async -> [String] {
        Self.unique(await translatePreservingOrder(meanings))
    }

    func translatePreservingOrder(_ meanings: [String]) async -> [String] {
        await translatePreservingOrder(meanings, priority: .automatic)
    }

    func translateManual(_ meanings: [String]) async -> [String] {
        Self.unique(await translatePreservingOrderManual(meanings))
    }

    func translatePreservingOrderManual(_ meanings: [String]) async -> [String] {
        await translatePreservingOrder(meanings, priority: .manual)
    }

    private func translatePreservingOrder(_ meanings: [String], priority: TranslationPriority) async -> [String] {
        var bestTranslation: [String]?

        for _ in 0..<2 {
            guard let systemTranslation = try? await Self.systemTranslationQueue.translate(meanings, priority: priority),
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

private enum TranslationPriority {
    case automatic
    case manual
}

private struct QueuedTranslationJob {
    let meanings: [String]
    let continuation: CheckedContinuation<[String], any Error>
}

private actor PriorityTranslationQueue {
    private var manualJobs: [QueuedTranslationJob] = []
    private var automaticJobs: [QueuedTranslationJob] = []
    private var isProcessing = false

    func translate(_ meanings: [String], priority: TranslationPriority) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            enqueue(
                QueuedTranslationJob(meanings: meanings, continuation: continuation),
                priority: priority
            )
        }
    }

    private func enqueue(_ job: QueuedTranslationJob, priority: TranslationPriority) {
        switch priority {
        case .manual:
            manualJobs.append(job)
        case .automatic:
            automaticJobs.append(job)
        }

        guard !isProcessing else {
            return
        }

        isProcessing = true
        Task {
            await processJobs()
        }
    }

    private func processJobs() async {
        while let job = nextJob() {
            do {
                let translated = try await SystemTranslationClient.translate(job.meanings)
                job.continuation.resume(returning: translated)
            } catch {
                job.continuation.resume(throwing: error)
            }
        }

        isProcessing = false
    }

    private func nextJob() -> QueuedTranslationJob? {
        if !manualJobs.isEmpty {
            return manualJobs.removeFirst()
        }

        if !automaticJobs.isEmpty {
            return automaticJobs.removeFirst()
        }

        return nil
    }
}

enum RussianMeaningTranslator {
    private static let translator = SystemRussianMeaningTranslator()

    static func translateLocally(_ meanings: [String]) -> [String] {
        translator.translateLocally(meanings)
    }

    static func translateAutomatically(_ meanings: [String]) async -> [String] {
        await translator.translate(meanings)
    }

    static func translate(_ meanings: [String]) async -> [String] {
        await translator.translate(meanings)
    }

    static func translatePreservingOrder(_ meanings: [String]) async -> [String] {
        await translator.translatePreservingOrder(meanings)
    }

    static func translateManual(_ meanings: [String]) async -> [String] {
        await translator.translateManual(meanings)
    }

    static func translatePreservingOrderManual(_ meanings: [String]) async -> [String] {
        await translator.translatePreservingOrderManual(meanings)
    }
}
