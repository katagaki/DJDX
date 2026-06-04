import SwiftUI
import WebKit

let sdvxInChartViewerUserScript = """
(function() {
  var style = document.createElement('style');
  style.textContent = ".btntop { display: none !important; }";
  (document.head || document.documentElement).appendChild(style);
})();
"""

struct SDVXInChartViewer: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var chart: SDVXInChart

    @State var webView = WKWebView()
    @State var isLoading: Bool = true
    @State var isShowingFallbackButton: Bool = false

    var body: some View {
        WebViewForSDVXIn(
            webView: $webView,
            isLoading: $isLoading,
            chart: chart
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
                        if let pageURL = chart.pageURL {
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
            await showFallbackAfterDelay()
        }
        .padding(0.0)
    }

    func refresh() {
        guard let pageURL = chart.pageURL else { return }
        webView.layer.opacity = 0.0
        withAnimation(.smooth.speed(2.0)) {
            isLoading = true
            isShowingFallbackButton = false
        } completion: {
            webView.load(URLRequest(url: pageURL))
            Task {
                await showFallbackAfterDelay()
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

    var chart: SDVXInChart

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.addUserScript(
            WKUserScript(source: sdvxInChartViewerUserScript,
                         injectionTime: .atDocumentEnd,
                         forMainFrameOnly: true)
        )
        let configuration = webView.configuration
        configuration.userContentController = contentController
        webView.navigationDelegate = context.coordinator
        webView.layer.opacity = 0.0
        if let pageURL = chart.pageURL {
            webView.load(URLRequest(url: pageURL))
        }
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
