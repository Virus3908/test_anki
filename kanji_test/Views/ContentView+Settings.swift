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
            .sheet(isPresented: $isAboutPresented) {
                aboutView()
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

    func aboutView() -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    aboutIntroView()

                    licenseCard(
                        title: "JMdict / KANJIDIC",
                        subtitle: "Слова, чтения, значения и часть kanji-данных",
                        license: "EDRDG licence / Creative Commons Attribution-ShareAlike 4.0",
                        links: [
                            ("EDRDG licence", "https://www.edrdg.org/edrdg/licence.html"),
                            ("JMdict project", "https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project")
                        ]
                    )

                    licenseCard(
                        title: "KanjiVG",
                        subtitle: "SVG-порядок черт для кандзи и каны",
                        license: "Creative Commons Attribution-ShareAlike 3.0",
                        links: [
                            ("KanjiVG", "https://github.com/KanjiVG/kanjivg"),
                            ("CC BY-SA 3.0", "https://creativecommons.org/licenses/by-sa/3.0/")
                        ]
                    )

                    licenseCard(
                        title: "Tatoeba",
                        subtitle: "Примеры предложений для слов",
                        license: "Creative Commons Attribution 2.0 France для текстовых предложений",
                        links: [
                            ("Terms of use", "https://tatoeba.org/en/terms_of_use"),
                            ("Using Tatoeba data", "https://en.wiki.tatoeba.org/articles/show/terms-of-use")
                        ]
                    )

                    licenseCard(
                        title: "kanjiapi.dev",
                        subtitle: "Удаленная загрузка списков, деталей кандзи и слов-примеров",
                        license: "API/project source is open; dictionary/stroke data keeps original source licences",
                        links: [
                            ("kanjiapi.dev", "https://kanjiapi.dev/"),
                            ("GitHub", "https://github.com/onlyskin/kanjiapi.dev")
                        ]
                    )

                    licenseCard(
                        title: "Apple Translation",
                        subtitle: "Системный перевод английских значений на русский",
                        license: "Системная функция Apple; переводы не являются исходными словарными данными",
                        links: [
                            ("Apple Translation", "https://developer.apple.com/documentation/translation")
                        ]
                    )
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppPalette.background)
            .foregroundStyle(AppPalette.text)
            .navigationTitle("Источники")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        isAboutPresented = false
                    }
                }
            }
        }
    }

    func aboutIntroView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Данные")
                .font(.title3.weight(.bold))

            Text("Локальный словарь слов подготовлен из JMdict. Порядок черт основан на KanjiVG. Примеры предложений загружаются из Tatoeba при открытии карточек слов.")
                .font(.footnote)
                .foregroundStyle(AppPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .appSurfaceCard()
    }

    func licenseCard(title: String, subtitle: String, license: String, links: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(license)
                .font(.caption)
                .foregroundStyle(AppPalette.mutedText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                ForEach(links, id: \.0) { link in
                    if let url = URL(string: link.1) {
                        Link(link.0, destination: url)
                            .font(.caption.weight(.semibold))
                    }
                }
            }
        }
        .padding(12)
        .appSurfaceCard()
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

    func frontSettingRow(for field: FrontFieldKind) -> some View {
        HStack(spacing: 10) {
            Toggle(field.title, isOn: binding(for: field))

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Button {
                    moveFrontField(field, direction: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(width: 28, height: 28)
                }
                .disabled(!canMoveFrontField(field, direction: -1))
                .accessibilityLabel("Переместить выше")

                Button {
                    moveFrontField(field, direction: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: 28, height: 28)
                }
                .disabled(!canMoveFrontField(field, direction: 1))
                .accessibilityLabel("Переместить ниже")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(AppPalette.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppPalette.background.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.28, dampingFraction: 0.95), value: frontFieldOrder)
    }

    func canMoveFrontField(_ field: FrontFieldKind, direction: Int) -> Bool {
        guard let currentIndex = frontFieldOrder.firstIndex(of: field) else {
            return false
        }

        return frontFieldOrder.indices.contains(currentIndex + direction)
    }

    func moveFrontField(_ field: FrontFieldKind, direction: Int) {
        guard let currentIndex = frontFieldOrder.firstIndex(of: field) else {
            return
        }

        let targetIndex = currentIndex + direction
        guard frontFieldOrder.indices.contains(targetIndex) else {
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
            return "Слова берутся локально из JMdict и группируются common-наборами."
        case .kana:
            return "Хирагана и катакана с просмотром карточек и тренировкой письма."
        }
    }

    func loadReviewMemory() async {
        await Task.yield()
        reviewStore = KanjiReviewStore.load()
        translationState.loadSavedWordTranslations()
    }

}
