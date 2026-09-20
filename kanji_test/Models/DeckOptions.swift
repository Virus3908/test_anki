import Foundation

nonisolated struct DeckOptions: Codable, Equatable, Sendable {
    var dailyNewCardLimit = 10
    /// Shared daily limit for review and new cards. The persisted property name
    /// is retained for Codable compatibility. nil means unlimited; 0 pauses
    /// both categories without interrupting intraday learning.
    var dailyReviewLimit: Int? = nil
    var desiredRetention = 0.9
    var maximumInterval = 36500
    var learningSteps: [Int] = [1, 10]
    var relearningSteps: [Int] = [10]
    var meaningLanguage: MeaningLanguage = .russian
    var showsPromptCharacters = false
    var showsPromptReading = true
    var showsPromptMeaning = false
    var frontFieldOrder: [FrontFieldKind] = [.readings, .meanings, .character]
    var builtInFrontFieldOrder: [BuiltInCardField]? = nil
    var builtInBackFieldOrder: [BuiltInCardField]? = nil
    var builtInFrontVisibleFields: Set<BuiltInCardField>? = nil
    var builtInBackVisibleFields: Set<BuiltInCardField>? = nil

    var validated: Self {
        var copy = self
        copy.dailyNewCardLimit = max(0, min(9999, dailyNewCardLimit))
        copy.dailyReviewLimit = dailyReviewLimit.map { max(0, min(9999, $0)) }
        copy.desiredRetention = desiredRetention.isFinite ? min(0.99, max(0.7, desiredRetention)) : 0.9
        copy.maximumInterval = max(1, min(36500, maximumInterval))
        copy.learningSteps = learningSteps.filter { (1..<1440).contains($0) }
        copy.relearningSteps = relearningSteps.filter { (1..<1440).contains($0) }
        if frontFieldOrder.count != FrontFieldKind.allCases.count || Set(frontFieldOrder).count != frontFieldOrder.count {
            copy.frontFieldOrder = [.readings, .meanings, .character]
        }
        return copy
    }
}
