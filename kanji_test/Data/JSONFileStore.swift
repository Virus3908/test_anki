import Foundation

nonisolated private struct StorageEnvelope<Value: Codable & Sendable>: Codable, Sendable {
    let schemaVersion: Int
    let payload: Value
}

nonisolated enum StorageFormatError: LocalizedError {
    case unsupportedVersion(Int)
    case recoveryRequired
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version): return "Формат данных версии \(version) не поддерживается этой версией приложения."
        case .recoveryRequired: return "Основной файл отсутствует. Доступна резервная копия."
        }
    }
}

/// One serialized owner for each file. Version 0 (unwrapped JSON) migrates on the next save.
actor JSONFileStore<Value: Codable & Sendable> {
    private let directory: FileManager.SearchPathDirectory
    private let subdirectory: String
    private let filename: String
    private let emptyValue: Value
    private var cachedValue: Value?
    private let currentVersion = 1

    init(directory: FileManager.SearchPathDirectory = .applicationSupportDirectory,
         subdirectory: String = "KanjiTrainer", filename: String, emptyValue: Value) {
        self.directory = directory
        self.subdirectory = subdirectory
        self.filename = filename
        self.emptyValue = emptyValue
    }

    func load() throws -> Value {
        if let cachedValue { return cachedValue }
        let url = try storageURL()
        let value: Value
        do {
            value = try decode(Data(contentsOf: url))
        } catch CocoaError.fileReadNoSuchFile {
            if FileManager.default.fileExists(atPath: backupURL(url).path) {
                throw StorageFormatError.recoveryRequired
            }
            value = emptyValue
        }
        cachedValue = value
        return value
    }

    func save(_ value: Value) throws {
        let previous = try load()
        let url = try storageURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encode(value)
        if directory == .applicationSupportDirectory {
            let backup = FileManager.default.fileExists(atPath: url.path) ? try encode(previous) : data
            try backup.write(to: backupURL(url), options: .atomic)
        }
        try data.write(to: url, options: .atomic)
        cachedValue = value
    }

    func update(_ change: @Sendable (inout Value) -> Void) throws {
        var value = try load()
        change(&value)
        try save(value)
    }

    func hasRecoverableBackup() -> Bool {
        guard let url = try? storageURL(), let data = try? Data(contentsOf: backupURL(url)) else { return false }
        return (try? decode(data)) != nil
    }

    func restoreBackup() throws -> Value {
        let url = try storageURL()
        let value = try decode(Data(contentsOf: backupURL(url)))
        // Preserve the unreadable original for possible later recovery.
        if FileManager.default.fileExists(atPath: url.path) {
            let archive = url.appendingPathExtension("unreadable-\(UUID().uuidString)")
            try FileManager.default.copyItem(at: url, to: archive)
        }
        try encode(value).write(to: url, options: .atomic)
        cachedValue = value
        return value
    }

    private func decode(_ data: Data) throws -> Value {
        let object = try JSONSerialization.jsonObject(with: data)
        if let dictionary = object as? [String: Any], let version = dictionary["schemaVersion"] as? Int {
            guard version == currentVersion else { throw StorageFormatError.unsupportedVersion(version) }
            return try JSONDecoder().decode(StorageEnvelope<Value>.self, from: data).payload
        }
        return try JSONDecoder().decode(Value.self, from: data)
    }

    private func encode(_ value: Value) throws -> Data {
        try JSONEncoder().encode(StorageEnvelope(schemaVersion: currentVersion, payload: value))
    }

    private func backupURL(_ url: URL) -> URL { url.appendingPathExtension("backup") }
    private func storageURL() throws -> URL {
        try FileManager.default.url(for: directory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(subdirectory, isDirectory: true).appendingPathComponent(filename)
    }
}
