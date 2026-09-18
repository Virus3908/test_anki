import XCTest
import WebKit
@testable import AnkiImport

@MainActor
final class AnkiWebRenderingTests: XCTestCase {
    func testLocalImageLoadsAndTemplateScriptIsBlocked() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("anki-web-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a4e0AAAAASUVORK5CYII=")!
        try png.write(to: directory.appendingPathComponent("猫.png"))
        let type = AnkiNoteType(id: 1, name: "Basic", isCloze: false, fields: ["Front"], templates: [
            .init(ordinal: 0, name: "Card", question: "{{Front}}<script>document.body.dataset.executed='yes'</script>", answer: "")
        ], css: "")
        let rendered = AnkiTemplateRenderer.render(card: .init(id: 3, noteID: 2, deckID: 4, ordinal: 0, scheduling: [:]),
            note: .init(id: 2, guid: "g", noteTypeID: 1, fields: ["<img src='猫.png'>[sound:音声.mp3]"], tags: []), type: type, deckName: "test", answer: false)
        let document = directory.appendingPathComponent("preview.html")
        try Data(rendered.html.utf8).write(to: document)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        let loaded = expectation(description: "Local card document loaded")
        let delegate = LoadDelegate(loaded: loaded, document: document)
        view.navigationDelegate = delegate
        view.loadFileURL(document, allowingReadAccessTo: directory)
        await fulfillment(of: [loaded], timeout: 15)
        XCTAssertNil(delegate.error)
        let imageWidth = try await view.evaluateJavaScript("document.images[0].naturalWidth") as? Int
        XCTAssertEqual(imageWidth, 1)
        let scriptRan = try await view.evaluateJavaScript("document.body.dataset.executed || 'no'") as? String
        XCTAssertEqual(scriptRan, "no")
        let audio = try await view.evaluateJavaScript("decodeURIComponent(document.querySelector('audio').src)") as? String
        XCTAssertTrue(audio?.hasSuffix("音声.mp3") == true)
        view.stopLoading()
    }

    private final class LoadDelegate: NSObject, WKNavigationDelegate {
        let loaded: XCTestExpectation
        let document: URL
        var error: Error?
        init(loaded: XCTestExpectation, document: URL) { self.loaded = loaded; self.document = document }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded.fulfill() }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            self.error = error
            loaded.fulfill()
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            action.navigationType == .other && action.targetFrame?.isMainFrame == true && action.request.url == document ? .allow : .cancel
        }
    }
}
