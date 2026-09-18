import SwiftUI
import AnkiImport

struct AnkiCollectionView: View {
    let summary: AnkiImportSummary
    let model: AnkiLibraryViewModel
    @State private var collection: AnkiCollection?
    @State private var mediaDirectory: URL?
    @State private var cardsByDeck: [Int64: [AnkiCard]] = [:]
    @State private var error: String?

    var body: some View {
        Group {
            if let collection, let mediaDirectory {
                List {
                    Section {
                        Text("\(collection.notes.count) заметок · \(collection.cards.count) карточек · \(collection.media.count) медиафайлов")
                        Text("Доступен просмотр карточек и всех полей. История Anki сохранена, но ещё не подключена к тренировкам приложения.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("Колоды") {
                        ForEach(collection.decks.sorted { $0.name < $1.name }) { deck in
                            let cards = cardsByDeck[deck.id] ?? []
                            NavigationLink {
                                AnkiDeckBrowserView(deck: deck, cards: cards, collection: collection, mediaDirectory: mediaDirectory)
                            } label: {
                                HStack {
                                    Text(deck.name)
                                    Spacer()
                                    Text("\(cards.count)").foregroundStyle(.secondary)
                                }
                            }.disabled(cards.isEmpty)
                        }
                    }
                    if !collection.warnings.isEmpty {
                        Section("Примечания к импорту") {
                            ForEach(collection.warnings, id: \.self) { Text($0).font(.footnote) }
                        }
                    }
                }
            } else if let error {
                ContentUnavailableView {
                    Label("Не удалось открыть колоду", systemImage: "exclamationmark.triangle")
                } description: { Text(error) } actions: {
                    Button("Повторить") { Task { await load() } }
                }
            } else { ProgressView("Открываю колоду…") }
        }
        .navigationTitle("Колоды Anki")
        .task { await load() }
    }

    private func load() async {
        guard collection == nil else { return }
        error = nil
        do {
            let (value, media) = try await model.open(summary)
            cardsByDeck = Dictionary(grouping: value.cards, by: \.deckID)
            mediaDirectory = media
            collection = value
        } catch { self.error = error.localizedDescription }
    }
}

struct AnkiDeckBrowserView: View {
    let deck: AnkiDeck
    let cards: [AnkiCard]
    let collection: AnkiCollection
    let mediaDirectory: URL
    @State private var index = 0
    @State private var answer = false
    @State private var showFields = false
    @State private var notes: [Int64: AnkiNote] = [:]
    @State private var types: [Int64: AnkiNoteType] = [:]

    var body: some View {
        VStack(spacing: 12) {
            if cards.indices.contains(index), let note = notes[cards[index].noteID], let type = types[note.noteTypeID] {
                let rendered = AnkiTemplateRenderer.render(card: cards[index], note: note, type: type, deckName: deck.name, answer: answer)
                HStack {
                    Text("\(index + 1) / \(cards.count)").monospacedDigit()
                    Spacer()
                    Button("Все поля", systemImage: "list.bullet.rectangle") { showFields = true }
                }.padding(.horizontal)
                AnkiHTMLView(html: rendered.html, mediaDirectory: mediaDirectory)
                    .id("\(cards[index].id)-\(answer)")
                if !rendered.warnings.isEmpty {
                    DisclosureGroup("Особенности шаблона") {
                        ScrollView { Text(rendered.warnings.joined(separator: "\n")).font(.caption) }.frame(maxHeight: 100)
                    }.font(.footnote).padding(.horizontal)
                }
                HStack {
                    Button { index -= 1; answer = false } label: { Image(systemName: "chevron.left") }
                        .disabled(index == 0).accessibilityLabel("Предыдущая карточка")
                    Spacer()
                    Button(answer ? "Показать вопрос" : "Показать ответ") { answer.toggle() }.buttonStyle(.borderedProminent)
                    Spacer()
                    Button { index += 1; answer = false } label: { Image(systemName: "chevron.right") }
                        .disabled(index + 1 == cards.count).accessibilityLabel("Следующая карточка")
                }.padding()
                .sheet(isPresented: $showFields) {
                    NavigationStack {
                        List {
                            Section("Тип заметки") { Text(type.name) }
                            ForEach(Array(type.fields.enumerated()), id: \.offset) { ordinal, name in
                                Section(name) { Text(note.fields[ordinal]).textSelection(.enabled) }
                            }
                            Section("Теги") { Text(note.tags.joined(separator: ", ")) }
                            Section("Идентификаторы Anki") {
                                Text("Note: \(note.id)\nGUID: \(note.guid)\nCard: \(cards[index].id)").textSelection(.enabled)
                            }
                        }.navigationTitle("Поля заметки")
                            .toolbar { Button("Готово") { showFields = false } }
                    }
                }
            } else { ProgressView() }
        }
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            notes = Dictionary(uniqueKeysWithValues: collection.notes.map { ($0.id, $0) })
            types = Dictionary(uniqueKeysWithValues: collection.noteTypes.map { ($0.id, $0) })
        }
    }
}
