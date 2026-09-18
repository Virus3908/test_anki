import Foundation
import Observation
import AnkiImport

@MainActor @Observable
final class AnkiLibraryViewModel {
    private let repository = AnkiRepository()
    var imports: [AnkiImportSummary] = []
    var isImporting = false
    var isLoaded = false
    var message: String?
    var canRestoreBackup = false

    func load() async {
        guard !isLoaded else { return }
        do { imports = try await repository.load(); isLoaded = true }
        catch { message = error.localizedDescription; canRestoreBackup = await repository.hasRecoverableBackup() }
    }

    func restoreBackup() async {
        do { imports = try await repository.restoreBackup(); isLoaded = true; canRestoreBackup = false }
        catch { message = error.localizedDescription }
    }

    func importPackage(_ url: URL) async {
        guard !isImporting, isLoaded else { return }
        isImporting = true
        defer { isImporting = false }
        do {
            let result = try await repository.importPackage(url)
            imports = try await repository.load()
            message = result.alreadyImported ? "Этот файл уже импортирован." :
                "Импортировано: \(result.summary.cardCount) карточек, \(result.summary.noteCount) заметок, \(result.summary.mediaCount) медиафайлов."
            if !result.summary.warnings.isEmpty { message = (message ?? "") + "\n\n" + result.summary.warnings.joined(separator: "\n") }
        } catch { message = error.localizedDescription }
    }

    func open(_ summary: AnkiImportSummary) async throws -> (AnkiCollection, URL) {
        let collection = try await repository.collection(summary)
        let media = try await repository.mediaDirectory(summary)
        return (collection, media)
    }
}
