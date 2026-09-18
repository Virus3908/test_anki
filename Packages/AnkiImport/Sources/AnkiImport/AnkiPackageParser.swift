import Foundation
import CryptoKit
import ZIPFoundation
import libzstd

public enum AnkiPackageParser {
    /// Destination must be new and private to this import. On error, no partial collection is retained.
    public static func extract(from source: URL, to destination: URL) throws -> AnkiCollection {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: destination.path) else { throw AnkiImportError.invalid("каталог импорта уже существует") }
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        var succeeded = false
        defer { if !succeeded { try? fm.removeItem(at: destination) } }
        let archive = try Archive(url: source, accessMode: .read)
        var entries: [String: Entry] = [:]
        for entry in archive {
            guard entries.count < 200_000, entries[entry.path] == nil else { throw AnkiImportError.invalid("слишком много файлов или повторяющиеся имена в ZIP") }
            entries[entry.path] = entry
        }
        var version = entries["collection.anki21"] == nil ? 1 : 2
        if let meta = entries["meta"] {
            let proto = try AnkiProtobuf(read(meta, archive: archive, limit: 1024))
            guard let parsed = Int(exactly: proto.numbers[1] ?? 0) else { throw AnkiImportError.invalid("неверная версия пакета") }
            version = parsed
        }
        guard (1...3).contains(version) else { throw AnkiImportError.unsupported(version) }
        let databaseName = version == 3 ? "collection.anki21b" : version == 2 ? "collection.anki21" : "collection.anki2"
        guard let databaseEntry = entries[databaseName] else { throw AnkiImportError.invalid("в архиве отсутствует \(databaseName)") }
        let databaseURL = destination.appendingPathComponent("collection.sqlite")
        var total: Int64 = 0
        try extract(databaseEntry, archive: archive, to: databaseURL, compressed: version == 3, limit: 512 * 1024 * 1024, total: &total)
        var collection = try AnkiDatabase(url: databaseURL).read()
        collection.prepareNativeFields()

        struct MediaEntry {
            let index: String
            let name: String
            let size: UInt64?
            let sha1: Data?
        }
        var media: [MediaEntry] = []
        if let entry = entries["media"] {
            let mapURL = destination.appendingPathComponent("media-map")
            try extract(entry, archive: archive, to: mapURL, compressed: version == 3, limit: 32 * 1024 * 1024, total: &total)
            let map = try Data(contentsOf: mapURL)
            if version == 3 {
                let proto = try AnkiProtobuf(map)
                for (index, data) in (proto.bytes[1] ?? []).enumerated() {
                    let item = try AnkiProtobuf(data)
                    media.append(.init(index: String(index), name: try item.string(1), size: item.numbers[2] ?? 0, sha1: item.bytes[3]?.last))
                }
            } else {
                media = try JSONDecoder().decode([String: String].self, from: map).map { .init(index: $0.key, name: $0.value, size: nil, sha1: nil) }
            }
        } else {
            collection.warnings.append("В пакете нет списка медиа. Если карточки ссылаются на картинки или звук, экспортируйте колоду с медиафайлами.")
        }
        guard media.count <= 200_000 else { throw AnkiImportError.limit }
        let mediaDirectory = destination.appendingPathComponent("media", isDirectory: true)
        try fm.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        var names = Set<String>()
        for item in media {
            try Task.checkCancellation()
            guard isSafeFilename(item.name), !item.index.isEmpty, item.index.allSatisfy({ $0.isASCII && $0.isNumber }),
                  names.insert(item.name.precomposedStringWithCanonicalMapping.lowercased()).inserted else {
                throw AnkiImportError.invalid("небезопасное или повторяющееся имя медиафайла: \(item.name)")
            }
            guard let entry = entries[item.index] else { throw AnkiImportError.invalid("медиафайл отсутствует в ZIP: \(item.name)") }
            let url = mediaDirectory.appendingPathComponent(item.name)
            let result = try extract(entry, archive: archive, to: url, compressed: version == 3, limit: 256 * 1024 * 1024, total: &total)
            if let expected = item.size, expected != UInt64(result.size) { throw AnkiImportError.invalid("неверный размер медиа: \(item.name)") }
            if let expected = item.sha1, expected != result.sha1 { throw AnkiImportError.invalid("повреждён медиафайл: \(item.name)") }
            collection.media.append(.init(name: item.name, size: result.size))
        }
        collection.media.sort { $0.name < $1.name }
        if collection.media.isEmpty && !collection.warnings.contains(where: { $0.contains("медиа") }) {
            collection.warnings.append("Медиафайлов в экспорте нет. Изображения и звуки будут доступны только если они включены в пакет.")
        }
        // Preserve the whole source DB (including revlog, configuration and unknown fields).
        try JSONEncoder().encode(collection).write(to: destination.appendingPathComponent("collection.json"), options: .atomic)
        succeeded = true
        return collection
    }

    public static func isSafeFilename(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\\") && !name.contains(":") &&
            !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    }

    private static func read(_ entry: Entry, archive: Archive, limit: Int) throws -> Data {
        guard entry.type == .file, entry.uncompressedSize <= UInt64(limit) else { throw AnkiImportError.limit }
        var data = Data()
        let crc = try archive.extract(entry) { chunk in
            guard chunk.count <= limit - data.count else { throw AnkiImportError.limit }
            data.append(chunk)
        }
        guard crc == entry.checksum else { throw AnkiImportError.invalid("ошибка контрольной суммы ZIP") }
        return data
    }

    @discardableResult
    private static func extract(_ entry: Entry, archive: Archive, to url: URL, compressed: Bool,
                                limit: Int, total: inout Int64) throws -> (size: Int, sha1: Data) {
        guard entry.type == .file, entry.uncompressedSize <= UInt64(limit) else { throw AnkiImportError.limit }
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw AnkiImportError.invalid("не удалось сохранить файл") }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        var size = 0
        var digest = Insecure.SHA1()
        func write(_ chunk: Data) throws {
            guard chunk.count <= limit - size, total + Int64(chunk.count) <= 4 * 1024 * 1024 * 1024 else { throw AnkiImportError.limit }
            try handle.write(contentsOf: chunk)
            digest.update(data: chunk)
            size += chunk.count
            total += Int64(chunk.count)
        }
        let decoder = compressed ? ZSTD_createDStream() : nil
        defer { if let decoder { ZSTD_freeDStream(decoder) } }
        if compressed {
            guard let decoder, ZSTD_isError(ZSTD_initDStream(decoder)) == 0 else { throw AnkiImportError.invalid("не удалось открыть Zstandard") }
            guard ZSTD_isError(ZSTD_DCtx_setParameter(decoder, ZSTD_d_windowLogMax, 27)) == 0 else { throw AnkiImportError.limit }
        }
        var remaining = 1
        var output = [UInt8](repeating: 0, count: 128 * 1024)
        let crc = try archive.extract(entry, bufferSize: 128 * 1024) { chunk in
            try Task.checkCancellation()
            guard let decoder else { try write(chunk); return }
            try chunk.withUnsafeBytes { inputBytes in
                var input = ZSTD_inBuffer(src: inputBytes.baseAddress, size: inputBytes.count, pos: 0)
                var filledOutput = false
                repeat {
                    let oldPosition = input.pos
                    let data = try output.withUnsafeMutableBytes { buffer -> Data in
                        var out = ZSTD_outBuffer(dst: buffer.baseAddress, size: buffer.count, pos: 0)
                        remaining = ZSTD_decompressStream(decoder, &out, &input)
                        guard ZSTD_isError(remaining) == 0 else { throw AnkiImportError.invalid("повреждён Zstandard") }
                        filledOutput = out.pos == out.size
                        return Data(bytes: buffer.baseAddress!, count: out.pos)
                    }
                    try write(data)
                    if input.pos == oldPosition && data.isEmpty { break }
                } while input.pos < input.size || (filledOutput && remaining != 0)
            }
        }
        guard crc == entry.checksum, !compressed || remaining == 0 else { throw AnkiImportError.invalid("повреждён или обрезан архив") }
        return (size, Data(digest.finalize()))
    }
}
