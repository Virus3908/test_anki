import SwiftUI

enum KanjiReadingFormatter {
    static func kunyomiText(for readings: [String]) -> AttributedString {
        guard !readings.isEmpty else {
            var empty = AttributedString("-")
            empty.foregroundColor = AppPalette.secondaryText
            return empty
        }

        var result = AttributedString()

        for (index, reading) in readings.enumerated() {
            if index > 0 {
                var separator = AttributedString(", ")
                separator.foregroundColor = AppPalette.text
                result += separator
            }

            let parts = reading.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            var kanjiReading = AttributedString(String(parts.first ?? ""))
            kanjiReading.foregroundColor = AppPalette.text
            result += kanjiReading

            if parts.count > 1 {
                var okurigana = AttributedString(String(parts[1]))
                okurigana.foregroundColor = AppPalette.mutedText
                result += okurigana
            }
        }

        return result
    }
}
