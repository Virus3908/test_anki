import SwiftUI

struct SettingsView: View, StudyViewStyling {
    @Bindable var settings: StudyPreferences
    let isBusy: Bool
    let canRestoreTranslations: Bool
    let onNextDay: () -> Void
    let onClearCache: () -> Void
    let onRestoreTranslations: () -> Void
    let initialDeck: StudyDeck?
    var importedDecks: [StudyDeck] = []
    @Environment(\.dismiss) var dismiss
    @State var isAboutPresented = false
    @State private var hasInitialized = false
    @State var selectedDeckID = ""
    @State var learningStepsText = ""
    @State var relearningStepsText = ""
    @State var learningStepsError: String?
    @State var relearningStepsError: String?
    var deckID: String? { selectedDeckID.isEmpty ? nil : selectedDeckID }
    var options: DeckOptions { settings.options(for: deckID) }
    var body: some View {
        settingsView()
            .onAppear {
                if !hasInitialized { selectedDeckID = initialDeck?.id ?? ""; loadStepFields(); hasInitialized = true }
            }
            .onChange(of: selectedDeckID) { loadStepFields() }
    }
    func optionBinding<Value>(_ path: WritableKeyPath<DeckOptions, Value>) -> Binding<Value> {
        Binding(get: { options[keyPath: path] }, set: { value in settings.updateOptions(for: deckID) { $0[keyPath: path] = value } })
    }
    func loadStepFields() {
        learningStepsText = options.learningSteps.map { "\($0)m" }.joined(separator: " ")
        relearningStepsText = options.relearningSteps.map { "\($0)m" }.joined(separator: " ")
        learningStepsError = nil
        relearningStepsError = nil
    }
    func saveSteps(_ text: String, relearning: Bool) {
        var steps: [Int] = []
        for token in text.split(whereSeparator: \.isWhitespace) {
            let suffix = token.last
            let number = suffix == "m" || suffix == "h" ? token.dropLast() : token[...]
            guard let value = Int(number), value > 0, value < 1440,
                  suffix != "h" || value < 24 else { setStepError(relearning); return }
            steps.append(suffix == "h" ? value * 60 : value)
        }
        if relearning { relearningStepsError = nil }
        else { learningStepsError = nil }
        guard steps != (relearning ? options.relearningSteps : options.learningSteps) else { return }
        settings.updateOptions(for: deckID) {
            if relearning { $0.relearningSteps = steps } else { $0.learningSteps = steps }
        }
    }
    func setStepError(_ relearning: Bool) {
        let message = "Введи шаги через пробел: например 1m 10m. Каждый шаг — от 1 минуты до 23 часов."
        if relearning { relearningStepsError = message } else { learningStepsError = message }
    }
}
