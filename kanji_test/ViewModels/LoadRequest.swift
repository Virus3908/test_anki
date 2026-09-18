import Foundation
import Observation

/// Invalidates stale completions and owns cancellation for screen loading.
@MainActor @Observable
final class LoadRequest {
    private(set) var id = UUID()
    @ObservationIgnored var task: Task<Void, Never>?

    func cancel() {
        id = UUID()
        task?.cancel()
        task = nil
    }

    deinit { task?.cancel() }
}
