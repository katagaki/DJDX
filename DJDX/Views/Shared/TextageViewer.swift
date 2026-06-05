import SwiftUI
import WebKit

struct TextageViewer: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var url: URL

    @State var webView = WKWebView()
    @State var isLoading: Bool = true
    @State var isShowingFallbackButton: Bool = false

    var body: some View {
        WebViewForTextage(
            webView: $webView,
            isLoading: $isLoading,
            url: url
        )
            .navigationTitle("ViewTitle.TextageViewer")
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
                            Text("Textage.FallbackMessage")
                            Link(destination: url) {
                                Label("Shared.OpenInSafari", systemImage: "safari")
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
        webView.layer.opacity = 0.0
        withAnimation(.smooth.speed(2.0)) {
            isLoading = true
            isShowingFallbackButton = false
        } completion: {
            webView.load(URLRequest(url: url))
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

struct WebViewForTextage: UIViewRepresentable {

    @Binding var webView: WKWebView
    @Binding var isLoading: Bool

    var url: URL

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.layer.opacity = 0.0
        #if DEBUG
        webView.isInspectable = true
        #endif
        webView.load(URLRequest(url: url))
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

        // didFinish never fires for Textage pages on iOS 18 (the page commits and
        // renders but the load event never completes), so reveal from didCommit too.
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
