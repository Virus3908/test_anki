import Foundation

/// Global request cap also covers concurrent example screens. Each URL/session
/// has one worker; cancellation removes a subscriber, cancelling the network
/// operation only when nobody else needs it.
actor TatoebaRequests {
    static let shared = TatoebaRequests()
    private struct Key: Hashable {
        let session: ObjectIdentifier
        let url: URL
    }
    private struct Pending {
        let task: Task<Data?, Never>
        var subscribers: Set<UUID>
    }
    private var pending: [Key: Pending] = [:]
    private var active: Set<UUID> = []
    private var waiting: [(UUID, CheckedContinuation<Bool, Never>)] = []

    func data(from url: URL, session: URLSession) async -> Data? {
        guard !Task.isCancelled else { return nil }
        let key = Key(session: ObjectIdentifier(session), url: url)
        let subscriber = UUID()
        let worker: Task<Data?, Never>
        if var entry = pending[key] {
            entry.subscribers.insert(subscriber)
            pending[key] = entry
            worker = entry.task
        } else {
            let operation = UUID()
            worker = Task.detached {
                guard await self.acquire(operation) else { return nil }
                var result: Data?
                if !Task.isCancelled {
                    do {
                        let (data, response) = try await session.data(from: url)
                        if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                            result = data
                        }
                    } catch { }
                }
                await self.release(operation)
                return result
            }
            pending[key] = Pending(task: worker, subscribers: [subscriber])
        }
        let data = await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            Task { await self.unsubscribe(subscriber, key: key) }
        }
        unsubscribe(subscriber, key: key)
        return Task.isCancelled ? nil : data
    }

    private func unsubscribe(_ subscriber: UUID, key: Key) {
        guard var entry = pending[key], entry.subscribers.remove(subscriber) != nil else { return }
        if entry.subscribers.isEmpty { entry.task.cancel(); pending[key] = nil }
        else { pending[key] = entry }
    }

    private func acquire(_ id: UUID) async -> Bool {
        guard !Task.isCancelled else { return false }
        if active.count < 3 { active.insert(id); return true }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled { continuation.resume(returning: false) }
                else { waiting.append((id, continuation)) }
            }
        } onCancel: { Task { await self.cancelWaiting(id) } }
    }

    private func cancelWaiting(_ id: UUID) {
        guard let index = waiting.firstIndex(where: { $0.0 == id }) else { return }
        waiting.remove(at: index).1.resume(returning: false)
    }

    private func release(_ id: UUID) {
        active.remove(id)
        if !waiting.isEmpty {
            let (next, continuation) = waiting.removeFirst()
            active.insert(next)
            continuation.resume(returning: true)
        }
    }
}
