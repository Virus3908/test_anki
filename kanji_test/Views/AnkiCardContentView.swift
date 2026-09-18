import SwiftUI
import AnkiImport

/// Shared by deck preview and SRS training; the imported HTML stays inside the standard app card.
struct AnkiCardContentView: View {
    let card: AnkiStudyCard
    let answer: Bool
    @State private var showFields = false

    var body: some View {
        let rendered = AnkiTemplateRenderer.render(card: card.card, note: card.note, type: card.noteType,
                                                   deckName: card.deckName, answer: answer)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(answer ? "Ответ" : "Задание")
                    .font(.caption.weight(.bold)).textCase(.uppercase)
                Spacer()
                Button("Все поля", systemImage: "list.bullet.rectangle") { showFields = true }
                    .font(.caption)
            }.foregroundStyle(AppPalette.secondaryText)
            AnkiHTMLView(html: rendered.html, mediaDirectory: card.mediaDirectory)
                .id("\(card.id)-\(answer)")
                .frame(minHeight: 240)
            if !rendered.warnings.isEmpty {
                DisclosureGroup("Особенности шаблона") {
                    ScrollView { Text(rendered.warnings.joined(separator: "\n")).font(.caption) }
                        .frame(maxHeight: 90)
                }.font(.caption).foregroundStyle(AppPalette.secondaryText)
            }
        }
        .padding(18).appSurfaceCard()
        .sheet(isPresented: $showFields) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(card.noteType.name).font(.headline)
                        ForEach(Array(card.noteType.fields.enumerated()), id: \.offset) { ordinal, name in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(name).font(.caption.weight(.bold)).foregroundStyle(AppPalette.secondaryText)
                                Text(card.note.fields[safe: ordinal] ?? "").textSelection(.enabled)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(12).appSurfaceCard()
                        }
                        if !card.note.tags.isEmpty { Text(card.note.tags.joined(separator: ", ")).font(.footnote) }
                    }.padding(20)
                }.background(AppPalette.background).foregroundStyle(AppPalette.text)
                    .navigationTitle("Поля заметки")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("Готово") { showFields = false } }
            }
        }
    }
}
