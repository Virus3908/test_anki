import SwiftUI

struct SettingsView: View, StudyViewStyling {
    enum FocusedField: Hashable {
        case dailyNewLimit
        case dailyReviewLimit
        case maximumInterval
        case learningStep(Int)
        case relearningStep(Int)
    }

    @Bindable var settings: StudyPreferences
    let isBusy: Bool
    let canRestoreTranslations: Bool
    let onNextDay: () -> Void
    let onClearCache: () -> Void
    let onRestoreTranslations: () -> Void
    let onResetDeckProgress: (StudyDeck) -> Void
    let initialDeck: StudyDeck?
    var importedDecks: [StudyDeck] = []
    @Environment(\.dismiss) var dismiss
    @State var isAboutPresented = false
    @State var isResetConfirmationPresented = false
    @State var sample = SpeechService()
    @AppStorage("ankiCardDisplayMode") var ankiCardDisplayMode = "native"
    @State private var hasInitialized = false
    @State var selectedDeckID = ""
    @State var dailyNewLimitText = ""
    @State var dailyReviewLimitText = ""
    @State var maximumIntervalText = ""
    @State var learningStepTexts: [String] = []
    @State var relearningStepTexts: [String] = []
    @State var learningStepsError: String?
    @State var relearningStepsError: String?
    @FocusState var focusedField: FocusedField?
    var deckID: String? { selectedDeckID.isEmpty ? nil : selectedDeckID }
    var selectedDeckTitle: String {
        guard !selectedDeckID.isEmpty else { return "По умолчанию" }
        guard let deck = (StudyDeck.builtIn + importedDecks).first(where: { $0.id == selectedDeckID }) else {
            return "Выбранная колода"
        }
        return "\(deck.mode.title): \(deck.title)"
    }
    var options: DeckOptions { settings.options(for: deckID) }
    var selectedDeck: StudyDeck? {
        (StudyDeck.builtIn + importedDecks).first { $0.id == selectedDeckID }
    }
    var body: some View {
        settingsView()
            .onAppear {
                if !hasInitialized { selectedDeckID = initialDeck?.id ?? ""; loadNumberFields(); hasInitialized = true }
            }
            .onChange(of: selectedDeckID) { loadNumberFields() }
            .onChange(of: focusedField) { oldField, newField in
                if let oldField, oldField != newField { commitNumberField(oldField) }
            }
    }
    func optionBinding<Value>(_ path: WritableKeyPath<DeckOptions, Value>) -> Binding<Value> {
        Binding(get: { options[keyPath: path] }, set: { value in settings.updateOptions(for: deckID) { $0[keyPath: path] = value } })
    }
    func loadNumberFields() {
        dailyNewLimitText = String(options.dailyNewCardLimit)
        dailyReviewLimitText = String(options.dailyReviewLimit ?? 200)
        maximumIntervalText = String(options.maximumInterval)
        let savedLearningSteps = options.learningSteps.map(String.init)
        learningStepTexts = savedLearningSteps + Array(
            repeating: "",
            count: max(0, 2 - savedLearningSteps.count)
        )
        let savedRelearningSteps = options.relearningSteps.map(String.init)
        relearningStepTexts = savedRelearningSteps.isEmpty ? [""] : savedRelearningSteps
        learningStepsError = nil
        relearningStepsError = nil
    }
    func digitsOnly(_ value: String) -> String {
        String(value.filter(\.isWholeNumber))
    }
    func dailyNewLimitBinding() -> Binding<String> {
        Binding(get: { dailyNewLimitText }, set: { value in
            dailyNewLimitText = digitsOnly(value)
            if let number = Int(dailyNewLimitText) {
                settings.updateOptions(for: deckID) { $0.dailyNewCardLimit = min(9999, number) }
            }
        })
    }
    func dailyReviewLimitBinding() -> Binding<String> {
        Binding(get: { dailyReviewLimitText }, set: { value in
            dailyReviewLimitText = digitsOnly(value)
            if let number = Int(dailyReviewLimitText) {
                settings.updateOptions(for: deckID) { $0.dailyReviewLimit = min(9999, number) }
            }
        })
    }
    func maximumIntervalBinding() -> Binding<String> {
        Binding(get: { maximumIntervalText }, set: { value in
            maximumIntervalText = digitsOnly(value)
            if let number = Int(maximumIntervalText), number > 0 {
                settings.updateOptions(for: deckID) { $0.maximumInterval = min(36500, number) }
            }
        })
    }
    func maximumIntervalStepperBinding() -> Binding<Int> {
        Binding(
            get: { options.maximumInterval },
            set: { value in
                maximumIntervalText = String(value)
                settings.updateOptions(for: deckID) { $0.maximumInterval = value }
            }
        )
    }
    func learningStepBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { learningStepTexts.indices.contains(index) ? learningStepTexts[index] : "" },
            set: { value in
                guard learningStepTexts.indices.contains(index) else { return }
                var updated = learningStepTexts
                updated[index] = digitsOnly(value)
                learningStepTexts = updated
                if !updated[index].isEmpty { saveStepFields(updated, relearning: false) }
            }
        )
    }
    func relearningStepBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { relearningStepTexts.indices.contains(index) ? relearningStepTexts[index] : "" },
            set: { value in
                guard relearningStepTexts.indices.contains(index) else { return }
                var updated = relearningStepTexts
                updated[index] = digitsOnly(value)
                relearningStepTexts = updated
                if !updated[index].isEmpty { saveStepFields(updated, relearning: true) }
            }
        )
    }
    func learningStepValueBinding(at index: Int) -> Binding<Int> {
        Binding(
            get: {
                guard learningStepTexts.indices.contains(index) else { return 1 }
                return Int(learningStepTexts[index]) ?? 1
            },
            set: { value in
                guard learningStepTexts.indices.contains(index) else { return }
                learningStepTexts[index] = String(value)
                saveStepFields(learningStepTexts, relearning: false)
            }
        )
    }
    func relearningStepValueBinding(at index: Int) -> Binding<Int> {
        Binding(
            get: {
                guard relearningStepTexts.indices.contains(index) else { return 1 }
                return Int(relearningStepTexts[index]) ?? 1
            },
            set: { value in
                guard relearningStepTexts.indices.contains(index) else { return }
                relearningStepTexts[index] = String(value)
                saveStepFields(relearningStepTexts, relearning: true)
            }
        )
    }
    func saveStepFields(_ fields: [String], relearning: Bool) {
        guard let lastFilledIndex = fields.lastIndex(where: { !$0.isEmpty }) else {
            return
        }
        let activeFields = fields[...lastFilledIndex]
        guard !activeFields.contains(where: \.isEmpty) else {
            setStepError("Заполни предыдущий шаг перед следующим.", relearning: relearning)
            return
        }
        var steps: [Int] = []
        for field in activeFields {
            guard let value = Int(field), (1..<1440).contains(value) else {
                setStepError("Каждый шаг должен быть от 1 до 1439 минут.", relearning: relearning)
                return
            }
            steps.append(value)
        }
        if relearning { relearningStepsError = nil }
        else { learningStepsError = nil }
        guard steps != (relearning ? options.relearningSteps : options.learningSteps) else { return }
        settings.updateOptions(for: deckID) {
            if relearning { $0.relearningSteps = steps } else { $0.learningSteps = steps }
        }
    }
    func setStepError(_ message: String, relearning: Bool) {
        if relearning { relearningStepsError = message } else { learningStepsError = message }
    }
    func commitNumberField(_ field: FocusedField) {
        switch field {
        case .dailyNewLimit:
            let value = min(9999, Int(dailyNewLimitText) ?? 1)
            dailyNewLimitText = String(value)
            settings.updateOptions(for: deckID) { $0.dailyNewCardLimit = value }
        case .dailyReviewLimit:
            let value = min(9999, Int(dailyReviewLimitText) ?? 1)
            dailyReviewLimitText = String(value)
            settings.updateOptions(for: deckID) { $0.dailyReviewLimit = value }
        case .maximumInterval:
            let value = min(36500, max(1, Int(maximumIntervalText) ?? 1))
            maximumIntervalText = String(value)
            settings.updateOptions(for: deckID) { $0.maximumInterval = value }
        case let .learningStep(index):
            guard learningStepTexts.indices.contains(index) else { return }
            if learningStepTexts[index].isEmpty { learningStepTexts[index] = "1" }
            saveStepFields(learningStepTexts, relearning: false)
        case let .relearningStep(index):
            guard relearningStepTexts.indices.contains(index) else { return }
            if relearningStepTexts[index].isEmpty { relearningStepTexts[index] = "1" }
            saveStepFields(relearningStepTexts, relearning: true)
        }
    }
    func finishEditing(_ field: FocusedField) {
        commitNumberField(field)
        focusedField = nil
    }
}
