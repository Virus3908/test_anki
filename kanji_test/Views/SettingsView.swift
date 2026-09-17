import SwiftUI

struct SettingsView: View, StudyViewStyling {
    @Bindable var settings: StudyPreferences
    let isBusy: Bool
    let canRestoreTranslations: Bool
    let onNextDay: () -> Void
    let onClearCache: () -> Void
    let onRestoreTranslations: () -> Void
    @Environment(\.dismiss) var dismiss
    @State var isAboutPresented = false
    var body: some View { settingsView() }
}
