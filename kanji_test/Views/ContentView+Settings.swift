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
                }
                .padding(20)
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
        }
    }

    func translationSettingsView() -> some View {
        settingsSection("Перевод") {
            Picker("Язык значений", selection: $meaningLanguage) {
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

    func frontSettingsView() -> some View {
        settingsSection("Лицевая сторона") {
            VStack(spacing: 8) {
                ForEach(frontFieldOrder) { field in
                    frontSettingRow(for: field)
                        .offset(y: draggedFrontField == field ? frontFieldDragOffset : 0)
                        .zIndex(draggedFrontField == field ? 1 : 0)
                        .simultaneousGesture(frontFieldDragGesture(for: field))
                }
            }
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
        .disabled(isLoadingDeck)
    }

    func frontSettingRow(for field: FrontFieldKind) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(AppPalette.mutedText)
                .frame(width: 18)

            Toggle(field.title, isOn: binding(for: field))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppPalette.background.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(draggedFrontField == field ? AppPalette.accent.opacity(0.55) : Color.clear, lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .scaleEffect(draggedFrontField == field ? 1.006 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.95), value: frontFieldOrder)
        .animation(.easeInOut(duration: 0.12), value: draggedFrontField)
    }

    func frontFieldDragGesture(for field: FrontFieldKind) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if draggedFrontField == nil {
                    draggedFrontField = field
                    frontFieldDragStartIndex = frontFieldOrder.firstIndex(of: field)
                }

                guard draggedFrontField == field else {
                    return
                }

                frontFieldDragOffset = clampedFrontFieldDragOffset(for: field, translation: value.translation.height)
            }
            .onEnded { value in
                moveFrontField(field, translation: value.translation.height)
                withAnimation(.easeOut(duration: 0.14)) {
                    frontFieldDragOffset = 0
                    frontFieldDragStartIndex = nil
                    draggedFrontField = nil
                }
            }
    }

    func clampedFrontFieldDragOffset(for field: FrontFieldKind, translation: CGFloat) -> CGFloat {
        let rowStride: CGFloat = 54
        guard let startIndex = frontFieldDragStartIndex else {
            return translation
        }

        let minOffset = CGFloat(-startIndex) * rowStride
        let maxOffset = CGFloat(frontFieldOrder.count - 1 - startIndex) * rowStride
        return min(max(translation, minOffset), maxOffset)
    }

    func moveFrontField(_ field: FrontFieldKind, translation: CGFloat) {
        let rowStride: CGFloat = 54
        guard let startIndex = frontFieldDragStartIndex,
              let currentIndex = frontFieldOrder.firstIndex(of: field) else {
            return
        }

        let steps = Int((translation / rowStride).rounded())
        let targetIndex = min(max(startIndex + steps, 0), frontFieldOrder.count - 1)
        guard targetIndex != currentIndex else {
            return
        }

        withAnimation(.easeOut(duration: 0.16)) {
            frontFieldOrder.move(
                fromOffsets: IndexSet(integer: currentIndex),
                toOffset: targetIndex > currentIndex ? targetIndex + 1 : targetIndex
            )
        }
    }

    func binding(for field: FrontFieldKind) -> Binding<Bool> {
        switch field {
        case .readings:
            return $showsPromptReading
        case .meanings:
            return $showsPromptMeaning
        case .character:
            return $showsPromptCharacters
        }
    }

    var trainingTitle: String {
        switch practiceMode {
        case .kanji:
            return selectedDeck.title
        case .words:
            return "Слова: \(selectedWordDeck.title)"
        case .kana:
            return selectedKanaDeck.title
        }
    }

    var startSubtitle: String {
        switch practiceMode {
        case .kanji:
            return "Первый запуск скачает весь пакет из kanjiapi.dev и сохранит его в кэш."
        case .words:
            return "Слова берутся локально из полного словаря и группируются диапазонами по частоте."
        case .kana:
            return "Хирагана и катакана с просмотром карточек и тренировкой письма."
        }
    }

    func loadReviewMemory() async {
        await Task.yield()
        reviewStore = KanjiReviewStore.load()
        wordMeaningTranslations = KanjiTranslationStore.loadWordTranslations()
    }

}
