import Foundation
import Observation

@MainActor
@Observable
final class TranslationViewModel {
    enum RequestKind { case automaticTranslation, manualTranslation, automaticExamples, manualExamples }
    struct Request { let id: UUID; let kind: RequestKind }
    private(set) var store = TranslationStore()
    private(set) var canRestoreBackup = false
    private(set) var requests: [TranslationBlockKey: Request] = [:]
    var kanjiUsageExamples: [String: [KanjiExample]] = [:]
    var wordUsageExamples: [String: [WordUsageExample]] = [:]
    @ObservationIgnored private var manualTasks: [TranslationBlockKey: Task<Void, Never>] = [:]
    let repository: any TranslationPersisting
    let translator: any MeaningTranslating
    let kanjiProvider: any KanjiProviding
    let wordProvider: any WordExampleProviding
    let errors: StorageStatus

    init(repository: any TranslationPersisting, translator: any MeaningTranslating,
         kanjiProvider: any KanjiProviding, wordProvider: any WordExampleProviding, errors: StorageStatus) {
        self.repository = repository
        self.translator = translator
        self.kanjiProvider = kanjiProvider
        self.wordProvider = wordProvider
        self.errors = errors
    }

    func loadSavedTranslations() async {
        do { store = try await repository.load(); canRestoreBackup = false }
        catch {
            canRestoreBackup = await repository.hasRecoverableBackup()
            errors.report("Не удалось загрузить переводы.", error: error)
        }
    }

    func restoreBackup() async {
        cancelRequests()
        do { store = try await repository.restoreBackup(); canRestoreBackup = false }
        catch { errors.report("Не удалось восстановить переводы.", error: error) }
    }

    func cancelRequests() {
        for task in manualTasks.values { task.cancel() }
        manualTasks.removeAll()
        requests.removeAll()
    }

    func clearLoadedExamples() {
        cancelRequests()
        kanjiUsageExamples.removeAll()
        wordUsageExamples.removeAll()
    }

    func begin(_ key: TranslationBlockKey, kind: RequestKind) -> UUID {
        let id = UUID()
        requests[key] = Request(id: id, kind: kind)
        return id
    }
    func beginAutomatic(_ key: TranslationBlockKey, kind: RequestKind) -> UUID? {
        if let request = requests[key], request.kind == .manualTranslation || request.kind == .manualExamples {
            return nil
        }
        // A replacement view task must not be blocked by a cancelled task still unwinding.
        return begin(key, kind: kind)
    }
    func current(_ id: UUID, key: TranslationBlockKey) -> Bool { !Task.isCancelled && requests[key]?.id == id }
    func end(_ id: UUID, key: TranslationBlockKey) {
        if requests[key]?.id == id { requests[key] = nil; manualTasks[key] = nil }
    }
    func runManual(_ key: TranslationBlockKey, kind: RequestKind,
                   operation: @escaping @MainActor (UUID) async -> Void) {
        manualTasks[key]?.cancel()
        let id = begin(key, kind: kind)
        manualTasks[key] = Task { [weak self] in
            defer { self?.end(id, key: key) }
            await operation(id)
        }
    }

    func cached(_ key: TranslationBlockKey, source: [String]) -> [String]? {
        guard let record = store.entries[key.storageKey], record.matches(source) else { return nil }
        return record.texts
    }

    func translate(_ key: TranslationBlockKey, texts: [String], source: [String], manual: Bool,
                   id: UUID, legacy: [String]? = nil) async {
        guard current(id, key: key), !texts.isEmpty else { return }
        if !manual, cached(key, source: source) != nil { return }
        let translated: [String]
        if !manual, let legacy, legacy.count == texts.count {
            translated = legacy
        } else {
            let indices = texts.indices.filter { !texts[$0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            guard !indices.isEmpty else { return }
            let input = indices.map { texts[$0] }
            let result = manual ? await translator.translatePreservingOrderManual(input) : await translator.translatePreservingOrder(input)
            guard result.count == input.count else { return }
            var output = texts
            for (index, text) in zip(indices, result) { output[index] = text }
            translated = output
        }
        guard current(id, key: key), translated.count == texts.count else { return }
        // An unavailable translator returns the originals. Keep that result retryable.
        guard zip(translated, texts).contains(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare($1.trimmingCharacters(in: .whitespacesAndNewlines)) != .orderedSame
        }) else { return }
        let record = StoredTextTranslation(source: source, sourceLanguage: "en", targetLanguage: "ru", texts: translated)
        do {
            try await repository.save(record, for: key)
            guard current(id, key: key) else { return }
            store.entries[key.storageKey] = record
            store.removeLegacy(key)
        } catch {
            if current(id, key: key) { errors.report("Не удалось сохранить перевод.", error: error) }
        }
    }

    func translateAutomatically(_ key: TranslationBlockKey, texts: [String], source: [String], legacy: [String]? = nil) async {
        guard cached(key, source: source) == nil,
              let id = beginAutomatic(key, kind: .automaticTranslation) else { return }
        defer { end(id, key: key) }
        await translate(key, texts: texts, source: source, manual: false, id: id, legacy: legacy)
    }

    func isAutomaticallyTranslating(_ key: TranslationBlockKey) -> Bool { requests[key]?.kind == .automaticTranslation }
    func isManuallyTranslating(_ key: TranslationBlockKey) -> Bool { requests[key]?.kind == .manualTranslation }
    func isAutomaticallyLoadingExamples(_ key: TranslationBlockKey) -> Bool { requests[key]?.kind == .automaticExamples }
    func isManuallyReloadingExamples(_ key: TranslationBlockKey) -> Bool { requests[key]?.kind == .manualExamples }
}
