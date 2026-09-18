import Foundation
import Observation

@MainActor
@Observable
final class StorageStatus {
    private var messages: [String] = []
    var message: String? {
        get { messages.first }
        set {
            if let newValue {
                if !messages.contains(newValue) { messages.append(newValue) }
            } else if !messages.isEmpty {
                messages.removeFirst()
            }
        }
    }

    func report(_ operation: String, error: Error) {
        message = "\(operation)\n\(error.localizedDescription)"
    }
}
