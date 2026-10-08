import SwiftUI
import WebKit

/// The chat shell, navigation, compositing and keyboard are entirely SwiftUI.
/// WebKit is used only as a constrained, scroll-disabled rich text canvas so
/// Markdown, KaTeX HTML+MathML and syntax coloring exactly share the AERTEX
/// Intelligence website's renderer (bundled source: AERTEXRichMessage.js).
/// No site navigation, login cookies, remote HTML pages, or JS execution from
/// model-generated content is permitted.
struct AERTEXRichMessageView: View {
    let markdown: String
    let streaming: Bool
    @State private var measuredHeight: CGFloat = 35
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AERTEXRichWebCanvas(
            markdown: markdown,
            streaming: streaming,
            colorScheme: colorScheme,
            measuredHeight: $measuredHeight
        )
        .frame(height: measuredHeight)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(markdown)
    }
}

private struct AERTEXRichWebCanvas: UIViewRepresentable {
    let markdown: String
    let streaming: Bool
    let colorScheme: ColorScheme
    @Binding var measuredHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $measuredHeight)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "contentHeight")
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light

        // The source is version-controlled, never downloaded as HTML from a
        // server. It is intentionally injected as code; user/model content isn't.
        let renderer = loadRendererSource()
        let html = #"""
        <!doctype html><html lang="zh-cn">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
          <meta http-equiv="Content-Security-Policy"
            content="default-src 'none'; script-src 'unsafe-inline' https://cdn.jsdelivr.net; style-src 'unsafe-inline' https://cdn.jsdelivr.net; font-src https://cdn.jsdelivr.net data:; img-src data: https:; connect-src 'none'; form-action 'none'; base-uri 'none';">
          <style>
            :root { color-scheme: light dark; --text:#161616; --muted:#6d6d70; --line:rgba(0,0,0,.14); --panel:#fff; --panel2:rgba(130,130,130,.12) }
            @media(prefers-color-scheme: dark) {
              :root { --text:#f5f5f7; --muted:#ababaf; --line:rgba(255,255,255,.18); --panel:#222; --panel2:rgba(155,155,155,.15) }
            }
            html, body { background:transparent!important; margin:0!important; padding:0!important; min-height:0; }
            body { color:var(--text); font:-apple-system-body; font-family:-apple-system,system-ui,sans-serif; line-height:1.65; overflow:hidden; }
            #aertex-message { width:100%; min-height:18px; }
            .richMarkdown { font-size: 16px; }
            .richMarkdown * { max-width:100%; box-sizing:border-box }
            .richMarkdown .tableScroll, .richMarkdown .mathBlock { max-width:100%; overflow-x:auto; }
          </style>
        </head>
        <body><main id="aertex-message" aria-live="off"></main>
        <script>
        \#(renderer)
        </script></body></html>
        """#
        context.coordinator.webView = webView
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        context.coordinator.render(markdown: markdown, streaming: streaming)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "contentHeight")
        webView.navigationDelegate = nil
        webView.stopLoading()
    }

    private func loadRendererSource() -> String {
        if let path = Bundle.module.url(
            forResource: "AERTEXRichMessage",
            withExtension: "js",
            subdirectory: "Resources"
        ), let contents = try? String(contentsOf: path, encoding: .utf8) {
            return contents
        }
        // Explicit failure instead of silently displaying raw LaTeX as if
        // identical to the AERTEX website.
        return "window.__aertexRenderMessage = function() {};";
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        private var height: Binding<CGFloat>
        weak var webView: WKWebView?
        private var ready = false
        private var lastRenderedText: String?
        private var lastRenderedStreaming: Bool?
        private var pendingText = ""
        private var pendingStreaming = false

        init(height: Binding<CGFloat>) {
            self.height = height
        }

        func render(markdown: String, streaming: Bool) {
            pendingText = markdown
            pendingStreaming = streaming
            guard ready, let webView,
                  lastRenderedText != markdown || lastRenderedStreaming != streaming else { return }
            lastRenderedText = markdown
            lastRenderedStreaming = streaming
            guard let encoded = markdown.data(using: .utf8)?.base64EncodedString() else { return }
            let js = "window.__aertexRenderMessage('\(encoded)', \(streaming ? "false" : "true"));"
            webView.evaluateJavaScript(js) { _, error in
                if let error { NSLog("AERTEX Rich render: %@", error.localizedDescription) }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            ready = true
            render(markdown: pendingText, streaming: pendingStreaming)
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "contentHeight",
                  let value = message.body as? NSNumber else { return }
            let proposed = CGFloat(truncating: value)
            guard proposed.isFinite, proposed >= 18, proposed < 120_000 else { return }
            DispatchQueue.main.async {
                if abs(self.height.wrappedValue - proposed) >= 1 {
                    self.height.wrappedValue = proposed
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
            if ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                UIApplication.shared.open(url)
            }
        }
    }
}
