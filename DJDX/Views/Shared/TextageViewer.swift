import SwiftUI
import WebKit

let textageIIDXURL: URL = URL(string: """
https://textage.cc/score/index.html
""")!

struct TextageViewer: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var songTitle: String
    var level: IIDXLevel
    var playSide: IIDXPlaySide
    var playType: IIDXPlayType

    @State var webView = WKWebView()
    @State var isLoading: Bool = true
    @State var isShowingFallbackButton: Bool = false

    init(songTitle: String, level: IIDXLevel, playSide: IIDXPlaySide, playType: IIDXPlayType) {
        self.songTitle = songTitle
        self.level = level
        self.playSide = playSide
        self.playType = playType
    }

    var body: some View {
        WebViewForTextage(
            webView: $webView,
            isLoading: $isLoading,
            songTitle: songTitle,
            level: level,
            playSide: playSide,
            playType: playType
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
                            Link(destination: textageIIDXURL) {
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
            webView.load(URLRequest(url: textageIIDXURL))
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

    var songTitle: String
    var level: IIDXLevel
    var playSide: IIDXPlaySide = .notApplicable
    var playType: IIDXPlayType = .single

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.layer.opacity = 0.0
        webView.load(URLRequest(url: textageIIDXURL))
        return webView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            songTitle: songTitle,
            level: level, playSide: playSide,
            playType: playType,
            updateTextageState: updateTextageState
        )
    }

    func updateUIView(_: WKWebView, context _: Context) {
        // Blank function to conform to protocol
    }

    func updateTextageState(_ isTextageReady: Bool) {
        if isTextageReady {
            webView.layer.opacity = 1.0
            isLoading = false
        } else {
            webView.layer.opacity = 0.0
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {

        var songTitle: String
        var level: IIDXLevel
        var playSide: IIDXPlaySide = .notApplicable
        var playType: IIDXPlayType = .single
        var updateTextageState: (Bool) -> Void

        // didFinish never fires for the Textage pages on iOS 18 (the page
        // commits and renders but the load event never completes), so we drive
        // the flow from didCommit instead. These guard against running twice
        // when both didCommit and didFinish fire (iOS 26).
        var hasInjectedNavigation: Bool = false
        var hasRevealedChart: Bool = false

        init(
            songTitle: String,
            level: IIDXLevel,
            playSide: IIDXPlaySide,
            playType: IIDXPlayType,
            updateTextageState: @escaping (Bool) -> Void
        ) {
            self.songTitle = songTitle
            self.level = level
            self.playSide = playSide
            self.playType = playType
            self.updateTextageState = updateTextageState
            super.init()
        }

        func handleNavigation(_ webView: WKWebView) {
            guard let urlString = webView.url?.absoluteString else { return }
            if urlString.starts(with: textageIIDXURL.absoluteString) {
                guard !hasInjectedNavigation else { return }
                hasInjectedNavigation = true
                webView.evaluateJavaScript(
                    textageNavigationJS
                        .replacingOccurrences(of: "%@1", with: levelValue())
                        .replacingOccurrences(of: "%@2", with: escapedForJavaScript(songTitle))
                ) { result, error in
                    #if DEBUG
                    debugPrint("[Textage] navJS result:", result ?? "nil",
                               "error:", error?.localizedDescription ?? "none")
                    #endif
                }
            } else {
                guard !hasRevealedChart else { return }
                hasRevealedChart = true
                self.updateTextageState(true)
            }
        }

        func webView(_ webView: WKWebView, didCommit _: WKNavigation!) {
            #if DEBUG
            debugPrint("[Textage] didCommit ->", webView.url?.absoluteString ?? "nil")
            #endif
            handleNavigation(webView)
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            #if DEBUG
            debugPrint("[Textage] didFinish ->", webView.url?.absoluteString ?? "nil")
            #endif
            handleNavigation(webView)
        }

        func escapedForJavaScript(_ string: String) -> String {
            string
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
        }

        // swiftlint: disable cyclomatic_complexity
        func levelValue() -> String {
            switch playType {
            case .single:
                switch playSide {
                case .side1P:
                    switch level {
                    case .normal: return "102"
                    case .hyper: return "103"
                    case .another: return "104"
                    case .leggendaria: return "105"
                    default: break
                    }
                case .side2P:
                    switch level {
                    case .normal: return "202"
                    case .hyper: return "203"
                    case .another: return "204"
                    case .leggendaria: return "205"
                    default: break
                    }
                default: break
                }
            case .double:
                if playSide == .notApplicable {
                    switch level {
                    case .normal: return "307"
                    case .hyper: return "308"
                    case .another: return "309"
                    case .leggendaria: return "310"
                    default: break
                    }
                }
            }
            return "102"
        }
        // swiftlint: enable cyclomatic_complexity

    }

}
