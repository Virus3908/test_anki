import SwiftUI

extension SettingsView {
    func settingsView() -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    deckSelectionView()
                    translationSettingsView()
                    learningSettingsView()
                    ankiDisplaySettingsView()
                    storageSettingsView()
                    aboutSettingsView()
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
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
            Text("Настройки для")
                .font(.subheadline.weight(.semibold))

            Menu {
                Picker("Колода", selection: $selectedDeckID) {
                    Text("По умолчанию").tag("")
                    ForEach(StudyDeck.builtIn + importedDecks) { deck in
                        Text("\(deck.mode.title): \(deck.title)").tag(deck.id)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.stack")
                        .foregroundStyle(AppPalette.accent)
                    Text(selectedDeckTitle)
                        .foregroundStyle(AppPalette.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.secondaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .settingsInputField()

            Text(deckID == nil ? "Эти настройки используют колоды, у которых ещё нет собственных параметров." : "Изменения применяются только к выбранной колоде.")
                .font(.caption).foregroundStyle(AppPalette.secondaryText)
        }
    }

    func learningSettingsView() -> some View {
        VStack(spacing: 16) {
            settingsSection("Дневные лимиты") {
                dailyLimitInput(title: "Новых карточек", text: dailyNewLimitBinding(), field: .dailyNewLimit) {
                    Stepper("Новых карточек", value: Binding(
                        get: { options.dailyNewCardLimit },
                        set: { value in
                            dailyNewLimitText = String(value)
                            settings.updateOptions(for: deckID) { $0.dailyNewCardLimit = value }
                        }
                    ), in: 0...9999)
                    .labelsHidden()
                }
                Toggle("Все повторения без лимита", isOn: Binding(
                    get: { options.dailyReviewLimit == nil },
                    set: { enabled in
                        settings.updateOptions(for: deckID) { $0.dailyReviewLimit = enabled ? nil : 200 }
                        if !enabled { dailyReviewLimitText = "200" }
                    }
                ))
                if options.dailyReviewLimit != nil {
                    dailyLimitInput(title: "Повторений", text: dailyReviewLimitBinding(), field: .dailyReviewLimit) {
                        Stepper("Повторений", value: Binding(
                            get: { options.dailyReviewLimit ?? 200 },
                            set: { value in
                                dailyReviewLimitText = String(value)
                                settings.updateOptions(for: deckID) { $0.dailyReviewLimit = value }
                            }
                        ), in: 0...9999)
                        .labelsHidden()
                    }
                }
                Text("Лимиты действуют на выбранную колоду и сохраняются между запусками. Достигнутый лимит повторений приостанавливает новые карточки. Шаги обучения внутри дня завершаются без ограничения.")
                    .font(.caption).foregroundStyle(AppPalette.secondaryText)
            }
            settingsSection("Интервальное повторение · FSRS-6") {
                Text("FSRS подбирает дату следующего показа по тому, насколько хорошо ты помнишь каждую карточку.")
                    .font(.caption)
                    .foregroundStyle(AppPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                fsrsSetting(
                    title: "Целевое запоминание",
                    description: "\(Int((options.desiredRetention * 100).rounded()))% означает цель вспоминать примерно \(Int((options.desiredRetention * 100).rounded())) из 100 карточек. Выше процент — чаще повторения."
                ) {
                    HStack(spacing: 12) {
                        Text("\(Int((options.desiredRetention * 100).rounded()))%")
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(AppPalette.accent)
                            .frame(minWidth: 48, alignment: .leading)

                        Stepper("Целевое запоминание", value: optionBinding(\.desiredRetention), in: 0.7...0.99, step: 0.01)
                            .labelsHidden()

                        Text("70–99%")
                            .font(.caption)
                            .foregroundStyle(AppPalette.mutedText)
                    }
                }

                fsrsSetting(
                    title: "Самый долгий перерыв",
                    description: "FSRS не назначит следующую тренировку этой карточки позже указанного числа дней."
                ) {
                    HStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil")
                                .foregroundStyle(AppPalette.accent)
                            TextField("1", text: maximumIntervalBinding())
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .monospacedDigit()
                                .focused($focusedField, equals: .maximumInterval)
                                .accessibilityLabel("Максимальный интервал в днях")
                            Text("дней")
                                .foregroundStyle(AppPalette.secondaryText)
                            if focusedField == .maximumInterval {
                                Button("Готово") { finishEditing(.maximumInterval) }
                                    .font(.subheadline.weight(.semibold))
                                    .buttonStyle(.borderless)
                                    .accessibilityHint("Закрывает клавиатуру")
                            }
                        }
                        .settingsInputField()
                        if focusedField != .maximumInterval {
                            Stepper("Максимальный интервал", value: maximumIntervalStepperBinding(), in: 1...36500)
                                .labelsHidden()
                        }
                    }
                }

                fsrsSetting(
                    title: "Повторы новой карточки",
                    description: "Каждый короткий интервал вводится отдельно. После последнего шага карточка перейдёт к повторам по дням."
                ) {
                    ForEach(learningStepTexts.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(learningStepTitle(at: index))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppPalette.secondaryText)

                            HStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "pencil")
                                        .foregroundStyle(AppPalette.accent)
                                    TextField("1", text: learningStepBinding(at: index))
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .monospacedDigit()
                                        .focused($focusedField, equals: .learningStep(index))
                                        .accessibilityLabel(learningStepTitle(at: index))
                                    Text("минут")
                                        .foregroundStyle(AppPalette.secondaryText)
                                    if focusedField == .learningStep(index) {
                                        Button("Готово") { finishEditing(.learningStep(index)) }
                                            .font(.subheadline.weight(.semibold))
                                            .buttonStyle(.borderless)
                                    }
                                }
                                .settingsInputField(hasError: learningStepsError != nil)
                                if focusedField != .learningStep(index) {
                                    Stepper(learningStepTitle(at: index), value: learningStepValueBinding(at: index), in: 1...1439)
                                        .labelsHidden()
                                }
                            }
                        }
                    }
                    if let learningStepsError {
                        Text(learningStepsError).font(.caption).foregroundStyle(AppPalette.correction)
                    }
                }

                fsrsSetting(
                    title: "Повторы забытой карточки",
                    description: "После ответа «Снова» на изученную карточку она пройдёт эти короткие шаги ещё раз."
                ) {
                    ForEach(relearningStepTexts.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(index == 0 ? "Первый шаг · после «Снова»" : "Шаг \(index + 1) · после «Хорошо»")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppPalette.secondaryText)

                            HStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "pencil")
                                        .foregroundStyle(AppPalette.accent)
                                    TextField("1", text: relearningStepBinding(at: index))
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .monospacedDigit()
                                        .focused($focusedField, equals: .relearningStep(index))
                                        .accessibilityLabel("Шаг переучивания \(index + 1), минут")
                                    Text("минут")
                                        .foregroundStyle(AppPalette.secondaryText)
                                    if focusedField == .relearningStep(index) {
                                        Button("Готово") { finishEditing(.relearningStep(index)) }
                                            .font(.subheadline.weight(.semibold))
                                            .buttonStyle(.borderless)
                                    }
                                }
                                .settingsInputField(hasError: relearningStepsError != nil)
                                if focusedField != .relearningStep(index) {
                                    Stepper("Шаг переучивания \(index + 1)", value: relearningStepValueBinding(at: index), in: 1...1439)
                                        .labelsHidden()
                                }
                            }
                        }
                    }
                    if let relearningStepsError {
                        Text(relearningStepsError).font(.caption).foregroundStyle(AppPalette.correction)
                    }
                }

                Text("Все короткие шаги задаются в минутах. Новые параметры применяются со следующего ответа.")
                    .font(.caption)
                    .foregroundStyle(AppPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func fsrsSetting<Content: View>(
        title: String,
        description: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(description)
                .font(.caption)
                .foregroundStyle(AppPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
        .padding(12)
        .background(AppPalette.background.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func dailyLimitInput<Controls: View>(
        title: String,
        text: Binding<String>,
        field: FocusedField,
        @ViewBuilder controls: () -> Controls
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .foregroundStyle(AppPalette.accent)
                    TextField("1", text: text)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .focused($focusedField, equals: field)
                        .accessibilityLabel(title)
                    Text("карточек")
                        .foregroundStyle(AppPalette.secondaryText)
                    if focusedField == field {
                        Button("Готово") { finishEditing(field) }
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.borderless)
                    }
                }
                .settingsInputField()
                if focusedField != field {
                    controls()
                }
            }
        }
    }

    private func learningStepTitle(at index: Int) -> String {
        switch index {
        case 0: "Первый шаг · после «Снова»"
        case 1: "Второй шаг · после «Хорошо»"
        default: "Шаг \(index + 1) · после следующего «Хорошо»"
        }
    }

    private func ankiDisplaySettingsView() -> some View {
        settingsSection("Вид карточек Anki") {
            Picker("Отображение", selection: $ankiCardDisplayMode) {
                Text("Обычный вид").tag("native")
                Text("Шаблон Anki").tag("template")
            }
            .pickerStyle(.segmented)
            Text("Применяется ко всем колодам Anki в просмотре и тренировке. Обычный вид использует оформление приложения, шаблон — оформление исходной колоды.")
                .font(.caption)
                .foregroundStyle(AppPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
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

extension View {
    func settingsInputField(hasError: Bool = false) -> some View {
        padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(hasError ? AppPalette.correction : AppPalette.border, lineWidth: hasError ? 1.5 : 1)
            }
    }
}
