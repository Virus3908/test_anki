import SwiftUI
import WebKit

struct AnkiHTMLView: UIViewRepresentable {
    let html: String
    let mediaDirectory: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.html != html else { return }
        context.coordinator.html = html
        do {
            // Grant WebKit access only to this import's media, never the source DB or app storage.
            let document = context.coordinator.document ?? mediaDirectory.appendingPathComponent("preview-\(UUID().uuidString).html")
            try Data(html.utf8).write(to: document, options: .atomic)
            context.coordinator.document = document
            view.loadFileURL(document, allowingReadAccessTo: mediaDirectory)
        } catch {
            view.loadHTMLString("<p>Не удалось открыть карточку.</p>", baseURL: nil)
        }
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading()
        view.loadHTMLString("", baseURL: nil)
        if let document = coordinator.document { try? FileManager.default.removeItem(at: document) }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var html: String?
        var document: URL?
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            // Only allow the initial document, never links, forms or embedded navigation.
            if action.navigationType == .other && action.targetFrame?.isMainFrame == true &&
                (action.request.url == document || action.request.url?.absoluteString == "about:blank") {
                return .allow
            } else { return .cancel }
        }
    }
}
