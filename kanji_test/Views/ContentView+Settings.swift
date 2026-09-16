import SwiftUI

extension ContentView {
    func settingsView() -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    translationSettingsView()
                    learningSettingsView()
                    frontSettingsView()
                    storageSettingsView()
                    aboutSettingsView()
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppPalette.background)
            .foregroundStyle(AppPalette.text)
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        isSettingsPresented = false
                    }
                }
            }
            .sheet(isPresented: isAboutPresentedBinding) {
                aboutView()
            }
        }
    }

    func translationSettingsView() -> some View {
        settingsSection("Перевод") {
            Picker("Язык значений", selection: meaningLanguageBinding) {
                ForEach(MeaningLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }
            .pickerStyle(.segmented)

            Text(meaningLanguage == .russian ? "Показываем русский перевод через внутренний переводчик." : "Показываем исходные английские значения из источников.")
                .font(.caption)
                .foregroundStyle(AppPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func learningSettingsView() -> some View {
        settingsSection("Обучение") {
            Stepper(value: $kanjiDailyNewCardLimit, in: 1...50, step: 1) {
                HStack {
                    Text("Новых кандзи в день")
                    Spacer()
                    Text("\(kanjiDailyNewCardLimit)")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppPalette.text)
                }
            }

            Stepper(value: $kanjiLearningSuccessTarget, in: 1...6, step: 1) {
                HStack {
                    Text("Успехов для изучения")
                    Spacer()
                    Text("\(kanjiLearningSuccessTarget)")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppPalette.text)
                }
            }

            Text("Сессия начнется с карточек на повторение, затем добавит новые до этого лимита.")
                .font(.caption)
                .foregroundStyle(AppPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                reviewStore.advanceReviewDates(byDays: 1)
                ReviewRepository.save(reviewStore)
            } label: {
                Label("Перейти на следующий день", systemImage: "calendar.badge.clock")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(AppPalette.accent)
        }
    }

    func storageSettingsView() -> some View {
        settingsSection("Данные") {
            Button(role: .destructive) {
                clearDeckCache()
            } label: {
                Label("Очистить кэш", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(AppPalette.correction)

            Text("Удаляет загруженные карточки. Прогресс и сохраненные переводы остаются.")
                .font(.caption)
                .foregroundStyle(AppPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func aboutSettingsView() -> some View {
        settingsSection("О приложении") {
            Button {
                isAboutPresented = true
            } label: {
                Label("Источники и лицензии", systemImage: "info.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(AppPalette.accent)

            Text("Словари, порядок черт и примеры используют открытые источники с атрибуцией.")
                .font(.caption)
                .foregroundStyle(AppPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.secondaryText)
                .textCase(.uppercase)

            content()
        }
        .padding(12)
        .appSurfaceCard()
        .disabled(deckState.isLoadingDeck)
    }

}
