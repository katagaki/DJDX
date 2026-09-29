import SwiftUI
import WebKit

let sdvxInChartViewerCSS = """
.btntop { display: none !important; }
#reload_btn, .rebtn2 { display: none !important; }
body > table.t_ > tbody > tr:nth-child(2) > td.tbg > table > tbody > tr > td:nth-child(3) > table > tbody
  > tr:nth-child(3) > td > table:nth-child(2) {
  display: none !important;
}
img[src*="/logo/"] { display: none !important; }
#closeBtn { display: none !important; }
"""

let sdvxInChartViewerUserScript = """
(function() {
  var style = document.createElement('style');
  style.textContent = `\(sdvxInChartViewerCSS)`;
  (document.head || document.documentElement).appendChild(style);
})();
"""

private func makeSDVXInWebView() -> WKWebView {
    let contentController = WKUserContentController()
    contentController.addUserScript(
        WKUserScript(source: sdvxInChartViewerUserScript,
                     injectionTime: .atDocumentStart,
                     forMainFrameOnly: true)
    )
    let configuration = WKWebViewConfiguration()
    configuration.userContentController = contentController
    return WKWebView(frame: .zero, configuration: configuration)
}

struct SDVXInChartViewer: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var chart: SDVXInChart

    @State var webView = makeSDVXInWebView()
    @State var pageURL: URL?
    @State var isLoading: Bool = true
    @State var isShowingFallbackButton: Bool = false

    var body: some View {
        WebViewForSDVXIn(
            webView: $webView,
            isLoading: $isLoading
        )
        .navigationTitle("ViewTitle.SDVXInChartViewer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Shared.Refresh", systemImage: "arrow.clockwise") {
                    refresh()
                }
            }
        }
        .background {
            VStack(spacing: 16.0) {
                if isLoading {
                    ProgressView("Shared.Loading")
                }
                if isShowingFallbackButton {
                    VStack(spacing: 8.0) {
                        Text("SDVXInChartViewer.FallbackMessage")
                        if let pageURL = pageURL ?? chart.legacyPageURL {
                            Link(destination: pageURL) {
                                Label("Shared.OpenInSafari", systemImage: "safari")
                            }
                        }
                    }
                    .padding()
                    .background(Color(uiColor: colorScheme == .dark ?
                        .secondarySystemGroupedBackground :
                            .systemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 10.0))
                }
            }
        }
        .task {
            await load()
        }
        .padding(0.0)
    }

    func load() async {
        async let fallback: Void = showFallbackAfterDelay()
        if let resolvedURL = await chart.resolvePageURL() {
            pageURL = resolvedURL
            webView.load(URLRequest(url: resolvedURL))
        }
        await fallback
    }

    func refresh() {
        webView.layer.opacity = 0.0
        withAnimation(.smooth.speed(2.0)) {
            isLoading = true
            isShowingFallbackButton = false
        } completion: {
            Task {
                await load()
            }
        }
    }

    func showFallbackAfterDelay() async {
        try? await Task.sleep(for: .seconds(4.0))
        if isLoading {
            withAnimation(.smooth.speed(2.0)) {
                isShowingFallbackButton = true
            }
        }
    }
}

struct WebViewForSDVXIn: UIViewRepresentable {

    @Binding var webView: WKWebView
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.layer.opacity = 0.0
        #if DEBUG
        webView.isInspectable = true
        #endif
        return webView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(updateState: updateState)
    }

    func updateUIView(_: WKWebView, context _: Context) {
    }

    func updateState(_ isReady: Bool) {
        if isReady {
            webView.layer.opacity = 1.0
            isLoading = false
        } else {
            webView.layer.opacity = 0.0
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {

        var updateState: (Bool) -> Void
        var hasRevealed: Bool = false

        init(updateState: @escaping (Bool) -> Void) {
            self.updateState = updateState
            super.init()
        }

        func reveal() {
            guard !hasRevealed else { return }
            hasRevealed = true
            updateState(true)
        }

        func webView(_: WKWebView, didFinish _: WKNavigation!) {
            reveal()
        }

        func webView(_: WKWebView, didCommit _: WKNavigation!) {
            reveal()
        }
    }
}
