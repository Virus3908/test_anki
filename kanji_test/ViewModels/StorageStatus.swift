import Foundation
import Observation

@MainActor
@Observable
final class StorageStatus {
    var message: String?

    func report(_ operation: String, error: Error) {
        message = "\(operation)\n\(error.localizedDescription)"
    }
}
