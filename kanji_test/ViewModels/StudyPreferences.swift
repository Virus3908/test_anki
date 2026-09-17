import Foundation
import Observation

@MainActor
@Observable
final class StudyPreferences {
    private let defaults: UserDefaults
    var dailyNewCardLimit: Int { didSet { defaults.set(dailyNewCardLimit, forKey: "kanjiDailyNewCardLimit") } }
    var learningSuccessTarget: Int { didSet { defaults.set(learningSuccessTarget, forKey: "kanjiLearningSuccessTarget") } }
    var meaningLanguage: MeaningLanguage { didSet { defaults.set(meaningLanguage.rawValue, forKey: "meaningLanguage") } }
    var showsPromptCharacters: Bool { didSet { defaults.set(showsPromptCharacters, forKey: "showsPromptCharacters") } }
    var showsPromptReading: Bool { didSet { defaults.set(showsPromptReading, forKey: "showsPromptReading") } }
    var showsPromptMeaning: Bool { didSet { defaults.set(showsPromptMeaning, forKey: "showsPromptMeaning") } }
    var frontFieldOrder: [FrontFieldKind] { didSet { defaults.set(frontFieldOrder.map(\.rawValue), forKey: "frontFieldOrder") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        dailyNewCardLimit = max(0, defaults.object(forKey: "kanjiDailyNewCardLimit") as? Int ?? 10)
        learningSuccessTarget = max(1, defaults.object(forKey: "kanjiLearningSuccessTarget") as? Int ?? 2)
        meaningLanguage = MeaningLanguage(rawValue: defaults.string(forKey: "meaningLanguage") ?? "") ?? .russian
        showsPromptCharacters = defaults.bool(forKey: "showsPromptCharacters")
        showsPromptReading = defaults.object(forKey: "showsPromptReading") as? Bool ?? true
        showsPromptMeaning = defaults.bool(forKey: "showsPromptMeaning")
        let saved = (defaults.stringArray(forKey: "frontFieldOrder") ?? []).compactMap(FrontFieldKind.init(rawValue:))
        frontFieldOrder = saved.count == FrontFieldKind.allCases.count && Set(saved).count == saved.count
            ? saved : [.readings, .meanings, .character]
    }
}
