import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View { aboutView() }
    func aboutView() -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    aboutIntroView()

                    sectionTitle("Открытые библиотеки")

                    licenseCard(title: "FSRS-6 · swift-fsrs", subtitle: "Расчёт интервалов повторения",
                        license: "MIT · Copyright (c) 2023 Ben Smiley",
                        links: [("Исходный код", "https://github.com/open-spaced-repetition/swift-fsrs")])
                    bundledLicenseDisclosure("Полный текст лицензии swift-fsrs", resource: "FSRS-LICENSE")

                    licenseCard(title: "ZIPFoundation · Zstandard", subtitle: "Импорт архивов Anki",
                        license: "ZIPFoundation 0.9.20: MIT · Zstandard 1.5.7: BSD-3-Clause",
                        links: [("ZIPFoundation", "https://github.com/weichsel/ZIPFoundation"),
                                ("Zstandard", "https://github.com/facebook/zstd")])
                    bundledLicenseDisclosure("Полные тексты лицензий импорта", resource: "AnkiThirdPartyLicenses")

                    licenseCard(title: "SwiftSoup · LRUCache · swift-atomics",
                        subtitle: "Разбор и кэширование HTML-полей Anki",
                        license: "SwiftSoup 2.11.2: MIT · LRUCache 1.3.0: MIT · swift-atomics 1.3.1: Apache 2.0 с Swift Runtime Library Exception",
                        links: [
                            ("SwiftSoup", "https://github.com/scinfu/SwiftSoup"),
                            ("LRUCache", "https://github.com/nicklockwood/LRUCache"),
                            ("swift-atomics", "https://github.com/apple/swift-atomics")
                        ])
                    bundledLicenseDisclosure("Полные тексты лицензий HTML-парсера", resource: "AnkiHTMLParserLicenses")

                    sectionTitle("Источники данных")

                    licenseCard(
                        title: "JMdict / KANJIDIC",
                        subtitle: "Слова, чтения, значения и часть kanji-данных",
                        license: "Предоставлены Electronic Dictionary Research and Development Group (EDRDG). Данные используются согласно лицензии EDRDG / Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0).",
                        links: [
                            ("EDRDG licence", "https://www.edrdg.org/edrdg/licence.html"),
                            ("JMdict", "https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project"),
                            ("KANJIDIC", "https://www.edrdg.org/wiki/index.php/KANJIDIC_Project")
                        ]
                    )

                    licenseCard(
                        title: "KanjiVG",
                        subtitle: "Адаптированная офлайн-выборка SVG-порядка черт для кандзи и каны",
                        license: "Copyright Ulrich Apel and KanjiVG contributors · Creative Commons Attribution-ShareAlike 3.0",
                        links: [
                            ("KanjiVG", "https://github.com/KanjiVG/kanjivg"),
                            ("CC BY-SA 3.0", "https://creativecommons.org/licenses/by-sa/3.0/")
                        ]
                    )

                    licenseCard(
                        title: "Tatoeba",
                        subtitle: "Примеры предложений для слов и кандзи; у каждого загруженного предложения есть ссылка, ID, автор и лицензия",
                        license: "Для текстовых предложений по умолчанию применяется Creative Commons Attribution 2.0 France; отдельные предложения могут иметь другую совместимую лицензию. При повторном использовании необходимо соблюдать лицензию и указывать автора конкретного предложения.",
                        links: [
                            ("Terms of use", "https://tatoeba.org/en/terms_of_use"),
                            ("Using Tatoeba data", "https://en.wiki.tatoeba.org/articles/show/terms-of-use")
                        ]
                    )

                    licenseCard(
                        title: "kanjiapi.dev",
                        subtitle: "Источник локального снимка метаданных кандзи",
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
            .navigationTitle("Источники и лицензии")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }

    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(AppPalette.secondaryText)
            .textCase(.uppercase)
            .padding(.top, 4)
    }

    @ViewBuilder
    func bundledLicenseDisclosure(_ title: String, resource: String) -> some View {
        if let url = Bundle.main.url(forResource: resource, withExtension: "txt"),
           let license = try? String(contentsOf: url, encoding: .utf8) {
            DisclosureGroup(title) {
                Text(license)
                    .font(.caption2)
                    .foregroundStyle(AppPalette.secondaryText)
                    .textSelection(.enabled)
            }
        }
    }

    func aboutIntroView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Данные")
                .font(.title3.weight(.bold))

            Text("Здесь собраны источники данных и полные тексты лицензий открытых библиотек приложения. Локальный словарь подготовлен из JMdict, данные кандзи — из KANJIDIC через kanjiapi.dev, порядок черт основан на KanjiVG, а примеры предложений загружаются из Tatoeba.")
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

            VStack(alignment: .leading, spacing: 6) {
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
}
