import SwiftUI
import UniformTypeIdentifiers

struct AnkiLibraryView: View, StudyViewStyling {
    let model: AnkiLibraryViewModel
    let isBusy: Bool
    let onOpen: (StudyRoute) -> Void
    @State private var isImporterPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            primaryActionButton(title: "Импортировать колоду", systemImage: "square.and.arrow.down") {
                isImporterPresented = true
            }
            .disabled(model.isImporting || !model.isLoaded || isBusy)
            Text("Выбери .apkg или .colpkg в Файлах. При экспорте из Anki включи медиафайлы.")
                .font(.footnote).foregroundStyle(AppPalette.secondaryText)
            if model.isImporting {
                ProgressView("Импортирую карточки и медиа…")
            } else if !model.isLoaded {
                Button("Загрузить библиотеку повторно") { Task { await model.load() } }
                if model.canRestoreBackup {
                    Button("Восстановить библиотеку из резервной копии") { Task { await model.restoreBackup() } }
                }
            } else if model.decks.isEmpty {
                ContentUnavailableView("Пока нет колод", systemImage: "rectangle.stack", description: Text("Импортированные колоды появятся здесь."))
            }
            ForEach(model.decks) { deck in
                deckSelectionButton(title: deck.title, subtitle: "\(deck.cardCount) карточек", isDisabled: isBusy || model.isImporting) {
                    onOpen(.ankiDeck(deck))
                }
            }
        }
        .task { await model.load() }
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.data, .zip], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): if let url = urls.first { Task { await model.importPackage(url) } }
            case .failure(let error): model.message = error.localizedDescription
            }
        }
        .alert("Импорт Anki", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("Понятно") { model.message = nil }
        } message: { Text(model.message ?? "") }
    }
}
