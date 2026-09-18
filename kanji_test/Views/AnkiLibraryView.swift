import SwiftUI
import UniformTypeIdentifiers

struct AnkiLibraryView: View {
    let model: AnkiLibraryViewModel
    @State private var isImporterPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { isImporterPresented = true } label: {
                Label("Импортировать колоду", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isImporting || !model.isLoaded)
            Text("Выбери .apkg или .colpkg в Файлах. При экспорте из Anki включи медиафайлы.")
                .font(.footnote).foregroundStyle(AppPalette.secondaryText)
            if model.isImporting {
                ProgressView("Импортирую карточки и медиа…")
            } else if !model.isLoaded {
                Button("Загрузить библиотеку повторно") { Task { await model.load() } }
                if model.canRestoreBackup {
                    Button("Восстановить библиотеку из резервной копии") { Task { await model.restoreBackup() } }
                }
            } else if model.imports.isEmpty {
                ContentUnavailableView("Пока нет колод", systemImage: "rectangle.stack", description: Text("Импортированные колоды появятся здесь."))
            }
            ForEach(model.imports) { item in
                NavigationLink {
                    AnkiCollectionView(summary: item, model: model)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.filename).font(.headline)
                        Text("\(item.cardCount) карточек · \(item.mediaCount) медиафайлов")
                            .font(.subheadline).foregroundStyle(AppPalette.secondaryText)
                        Text(item.importedAt, style: .date).font(.caption).foregroundStyle(AppPalette.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(14).appSurfaceCard()
                }.buttonStyle(.plain)
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
