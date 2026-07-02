import SwiftUI
import WebKit

struct TextageViewer: View {

    enum Source {
        case legacy
        case chartViewer
    }

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var legacyURL: URL?
    var chartViewerURL: URL?

    @State var selectedSource: Source
    @State var webView = WKWebView()
    @State var isLoading: Bool = true
    @State var isShowingFallbackButton: Bool = false

    init(legacyURL: URL?, chartViewerURL: URL?) {
        self.legacyURL = legacyURL
        self.chartViewerURL = chartViewerURL
        self._selectedSource = State(initialValue: chartViewerURL != nil ? .chartViewer : .legacy)
    }

    var url: URL {
        switch selectedSource {
        case .legacy: legacyURL ?? chartViewerURL ?? Self.fallbackURL
        case .chartViewer: chartViewerURL ?? legacyURL ?? Self.fallbackURL
        }
    }

    private static let fallbackURL = URL(string: "https://textage.cc/")!

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
                if legacyURL != nil && chartViewerURL != nil {
                    ToolbarItem(placement: .principal) {
                        Picker(selection: $selectedSource) {
                            Text("TextageViewer.Source.ChartViewer")
                                .tag(Source.chartViewer)
                            Text("TextageViewer.Source.Legacy")
                                .tag(Source.legacy)
                        } label: {
                            Text("ViewTitle.TextageViewer")
                        }
                        .pickerStyle(.segmented)
                    }
                }
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
            .onChange(of: selectedSource) { _, _ in
                refresh()
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

    private static let chartViewerScript = WKUserScript(
        source: """
        if (location.hostname === "textage-chart-viewer.vercel.app") {
            try { localStorage.setItem("hideWelcomeDialog", "true"); } catch (error) {}
            const style = document.createElement("style");
            style.textContent = "header { display: none !important; }";
            document.documentElement.appendChild(style);
        }
        """,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    )

    func makeUIView(context: Context) -> WKWebView {
        webView.configuration.userContentController.addUserScript(Self.chartViewerScript)
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

        init(updateState: @escaping (Bool) -> Void) {
            self.updateState = updateState
            super.init()
        }

        func webView(_: WKWebView, didFinish _: WKNavigation!) {
            updateState(true)
        }

        func webView(_: WKWebView, didCommit _: WKNavigation!) {
            updateState(true)
        }
    }
}
