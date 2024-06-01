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

    var songTitle: String
    var level: IIDXLevel
    var playSide: IIDXPlaySide

    init(songTitle: String, level: IIDXLevel, playSide: IIDXPlaySide) {
        self.songTitle = songTitle
        self.level = level
        self.playSide = playSide
    }

    var body: some View {
        WebViewForTextageViewer(songTitle: songTitle, level: level, playSide: playSide)
            .navigationTitle("ViewTitle.TextageViewer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: textageIIDXURL) {
                        Label("Shared.OpenInSafari", systemImage: "safari")
                    }
                }
            }
            .background {
                VStack(spacing: 16.0) {
                    ProgressView("Importer.Web.Loading")
                }
            }
            .padding(0.0)
    }
}

struct WebViewForTextageViewer: UIViewRepresentable {

    let webView = WKWebView()
    var songTitle: String
    var level: IIDXLevel
    var playSide: IIDXPlaySide

    init(songTitle: String, level: IIDXLevel, playSide: IIDXPlaySide) {
        self.songTitle = songTitle
        self.level = level
        self.playSide = playSide
    }

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.layer.opacity = 0.0
        webView.load(URLRequest(url: textageIIDXURL))
        return webView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(songTitle: songTitle, level: level, playSide: playSide)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Blank function to conform to protocol
    }

    class Coordinator: NSObject, WKNavigationDelegate {

        let navigationJS = """
var levelSelectors = document.getElementsByName("djauto_opt")[0];
levelSelectors.value = "%@1";

var songNameTextField = document.getElementsByName("djauto")[0];
songNameTextField.value = "%@2";

do_djauto();
"""
        var songTitle: String
        var level: IIDXLevel
        var playSide: IIDXPlaySide

        init(songTitle: String, level: IIDXLevel, playSide: IIDXPlaySide) {
            self.songTitle = songTitle
            self.level = level
            self.playSide = playSide
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let webViewURL = webView.url {
                let urlString = webViewURL.absoluteString
                if urlString.starts(with: textageIIDXURL.absoluteString) {
                    webView.evaluateJavaScript(
                        self.navigationJS
                            .replacingOccurrences(of: "%@1", with: levelValue())
                            .replacingOccurrences(of: "%@2", with: songTitle)
                    )
                } else {
                    webView.layer.opacity = 1.0
                }
            }
        }

        // swiftlint: disable cyclomatic_complexity
        func levelValue() -> String {
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
            }
            return "102"
        }
        // swiftlint: enable cyclomatic_complexity

    }

}
