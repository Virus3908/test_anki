import SwiftUI

extension SettingsView {
    func settingsView() -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    deckSelectionView()
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
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isAboutPresented) {
                AboutView()
            }
        }
    }

    func translationSettingsView() -> some View {
        settingsSection("Перевод") {
            Picker("Язык значений", selection: optionBinding(\.meaningLanguage)) {
                ForEach(MeaningLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }
            .pickerStyle(.segmented)

            Text(options.meaningLanguage == .russian ? "Показываем русский перевод через внутренний переводчик." : "Показываем исходные английские значения из источников.")
                .font(.caption)
                .foregroundStyle(AppPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func deckSelectionView() -> some View {
        settingsSection("Колода") {
            Picker("Настроить", selection: $selectedDeckID) {
                Text("По умолчанию").tag("")
                ForEach(StudyDeck.builtIn) { deck in Text("\(deck.mode.title): \(deck.title)").tag(deck.id) }
            }
            Text(deckID == nil ? "Эти настройки используют колоды, у которых ещё нет собственных параметров." : "Изменения применяются только к выбранной колоде.")
                .font(.caption).foregroundStyle(AppPalette.secondaryText)
        }
    }

    func learningSettingsView() -> some View {
        VStack(spacing: 16) {
            settingsSection("Дневные лимиты") {
                Stepper("Новых карточек: \(options.dailyNewCardLimit)", value: optionBinding(\.dailyNewCardLimit), in: 0...9999)
                Toggle("Все повторения без лимита", isOn: Binding(
                    get: { options.dailyReviewLimit == nil },
                    set: { enabled in settings.updateOptions(for: deckID) { $0.dailyReviewLimit = enabled ? nil : 200 } }
                ))
                if let limit = options.dailyReviewLimit {
                    Stepper("Повторений: \(limit)", value: Binding(
                        get: { options.dailyReviewLimit ?? 200 },
                        set: { value in settings.updateOptions(for: deckID) { $0.dailyReviewLimit = value } }
                    ), in: 0...9999)
                }
                Text("Лимиты действуют на выбранную колоду и сохраняются между запусками. Достигнутый лимит повторений приостанавливает новые карточки. Шаги обучения внутри дня завершаются без ограничения.")
                    .font(.caption).foregroundStyle(AppPalette.secondaryText)
            }
            settingsSection("Интервальное повторение · FSRS-6") {
                Stepper("Целевое запоминание: \(Int((options.desiredRetention * 100).rounded()))%", value: optionBinding(\.desiredRetention), in: 0.7...0.99, step: 0.01)
                Text("Чем выше процент, тем чаще будут повторения. «Трудно» означает, что ответ вспомнил; если забыл — выбирай «Снова».")
                    .font(.caption).foregroundStyle(AppPalette.secondaryText)
                HStack {
                    Text("Максимальный интервал, дней")
                    TextField("Дни", value: optionBinding(\.maximumInterval), format: .number)
                        .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 90)
                }
                TextField("Шаги обучения: 1m 10m", text: $learningStepsText)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onSubmit { saveSteps(learningStepsText, relearning: false) }
                    .onChange(of: learningStepsText) { saveSteps(learningStepsText, relearning: false) }
                if let learningStepsError { Text(learningStepsError).font(.caption).foregroundStyle(AppPalette.correction) }
                TextField("Шаги переучивания: 10m", text: $relearningStepsText)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onSubmit { saveSteps(relearningStepsText, relearning: true) }
                    .onChange(of: relearningStepsText) { saveSteps(relearningStepsText, relearning: true) }
                if let relearningStepsError { Text(relearningStepsError).font(.caption).foregroundStyle(AppPalette.correction) }
                Text("Шаги задаются в минутах (m) или часах (h), через пробел. Пустое поле — сразу интервалы FSRS. Новые параметры применяются со следующего ответа.")
                    .font(.caption).foregroundStyle(AppPalette.secondaryText)
            }
        }
    }

    func storageSettingsView() -> some View {
        settingsSection("Данные") {
            Button("Перейти на следующий учебный день", systemImage: "calendar.badge.clock", action: onNextDay)
                .buttonStyle(.bordered).tint(AppPalette.accent)

            Button(role: .destructive) {
                onClearCache()
            } label: {
                Label("Очистить кэш", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(AppPalette.correction)

            if canRestoreTranslations {
                Button("Восстановить переводы из резервной копии", action: onRestoreTranslations)
            }
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
        .disabled(isBusy)
    }

}
