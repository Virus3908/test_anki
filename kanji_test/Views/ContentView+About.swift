import SwiftUI

extension ContentView {
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
}
