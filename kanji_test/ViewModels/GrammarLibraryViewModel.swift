import Foundation
import Observation

nonisolated struct GrammarSearchRecord: CardSearchRecord {
    let rule: GrammarRule
    var searchTerms: [String] {
        [rule.pattern, rule.reading ?? "", rule.romaji ?? "", rule.meaning,
         rule.localization?.meaningRU ?? "", rule.level.rawValue]
            + rule.tags + rule.categories.map(\.title)
    }
}

@MainActor
@Observable
final class GrammarLibraryViewModel {
    private(set) var rules: [GrammarRule] = []
    private(set) var results: [GrammarRule] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private var generation = 0
    @ObservationIgnored private var searchTask: Task<[GrammarRule], Error>?
    @ObservationIgnored private var index: CardSearchIndex<GrammarSearchRecord>?
    private let loader: GrammarDataLoader
    init(loader: GrammarDataLoader = .shared) { self.loader = loader }
    deinit { searchTask?.cancel() }

    func load() async {
        guard rules.isEmpty, !isLoading else { return }
        isLoading = true; error = nil
        defer { isLoading = false }
        do {
            let values = try await loader.allRules()
            let worker = Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                return CardSearchIndex(records: values.map(GrammarSearchRecord.init))
            }
            let prepared = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
            try Task.checkCancellation()
            rules = values; index = prepared
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }

    func invalidateSearch() {
        generation += 1
        searchTask?.cancel(); searchTask = nil
        results = []
    }

    func search(_ query: String, level: GrammarLevel, category: GrammarCategory?) async {
        invalidateSearch()
        let token = generation
        guard let index else { return }
        let values = rules
        let worker = Task.detached(priority: .userInitiated) {
            let matches = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? values : try index.search(query, limit: .max).records.map(\.rule)
            try Task.checkCancellation()
            return matches.filter { $0.level == level && (category == nil || $0.categories.contains(category!)) }
        }
        searchTask = worker
        do {
            let matches = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
            guard generation == token, !Task.isCancelled else { return }
            results = matches; searchTask = nil
        } catch is CancellationError { }
        catch { if generation == token { self.error = error.localizedDescription } }
    }
}
