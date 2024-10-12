//
//  TextageViewer.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/01.
//

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
            .toolbarBackground(.visible, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Shared.Refresh", systemImage: "arrow.clockwise") {
                        webView.layer.opacity = 0.0
                        withAnimation(.snappy.speed(2.0)) {
                            isLoading = true
                            isShowingFallbackButton = false
                        } completion: {
                            webView.load(URLRequest(url: textageIIDXURL))
                            Task {
                                await showFallbackAfterDelay()
                            }
                        }
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

    func showFallbackAfterDelay() async {
        try? await Task.sleep(for: .seconds(4.0))
        if isLoading {
            withAnimation(.snappy.speed(2.0)) {
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

    func updateUIView(_ uiView: WKWebView, context: Context) {
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

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let webViewURL = webView.url {
                let urlString = webViewURL.absoluteString
                if urlString.starts(with: textageIIDXURL.absoluteString) {
                    webView.evaluateJavaScript(
                        textageNavigationJS
                            .replacingOccurrences(of: "%@1", with: levelValue())
                            .replacingOccurrences(of: "%@2", with: songTitle)
                    )
                } else {
                    self.updateTextageState(true)
                }
            }
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
                switch playSide {
                case .notApplicable:
                    switch level {
                    case .normal: return "307"
                    case .hyper: return "308"
                    case .another: return "309"
                    case .leggendaria: return "310"
                    default: break
                    }
                default: break
                }
            }
            return "102"
        }
        // swiftlint: enable cyclomatic_complexity

    }

}
