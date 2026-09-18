import Foundation

/// Reads only the protobuf wire types used by Anki metadata, skipping unknown fields.
/// The original database remains available for data this app does not interpret.
struct AnkiProtobuf {
    var bytes: [Int: [Data]] = [:]
    var numbers: [Int: UInt64] = [:]

    init(_ data: Data) throws {
        let data = Array(data)
        var offset = 0
        func varint() throws -> UInt64 {
            var value: UInt64 = 0
            for shift in stride(from: 0, through: 63, by: 7) {
                guard offset < data.count else { throw AnkiImportError.invalid("обрезанные метаданные") }
                let byte = data[offset]
                offset += 1
                guard shift < 63 || byte <= 1 else { throw AnkiImportError.invalid("переполнение метаданных") }
                value |= UInt64(byte & 0x7f) << shift
                if byte & 0x80 == 0 { return value }
            }
            throw AnkiImportError.invalid("неверные метаданные")
        }
        while offset < data.count {
            let key = try varint()
            guard key >> 3 > 0, key >> 3 <= 536_870_911 else { throw AnkiImportError.invalid("неверный protobuf") }
            let field = Int(key >> 3)
            switch key & 7 {
            case 0: numbers[field] = try varint()
            case 1, 5:
                let count = key & 7 == 1 ? 8 : 4
                guard count <= data.count - offset else { throw AnkiImportError.invalid("обрезанный protobuf") }
                offset += count
            case 2:
                let size = try varint()
                guard size <= UInt64(data.count - offset) else { throw AnkiImportError.invalid("обрезанный protobuf") }
                bytes[field, default: []].append(Data(data[offset..<(offset + Int(size))]))
                offset += Int(size)
            default: throw AnkiImportError.invalid("неподдерживаемый protobuf")
            }
        }
    }

    func string(_ field: Int) throws -> String {
        guard let data = bytes[field]?.last else { return "" }
        guard let string = String(data: data, encoding: .utf8) else { throw AnkiImportError.invalid("неверная кодировка") }
        return string
    }
}
