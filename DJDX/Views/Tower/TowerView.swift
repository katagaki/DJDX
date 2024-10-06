//
//  TowerView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/06.
//

import SwiftUI
import WebKit

struct TowerView: View {

    @State var webView = WKWebView()

    var body: some View {
        NavigationStack {
            WebViewForTower(webView: $webView)
                .navigationTitle("ViewTitle.Tower")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Spacer()
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        HStack(alignment: .bottom, spacing: 4.0) {
                            LargeInlineTitle("ViewTitle.Tower")
                            Text("Shared.Beta")
                                .font(.caption)
                                .fontWeight(.black)
                                .foregroundStyle(.secondary)
                                .offset(y: -5.0)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Shared.Refresh", systemImage: "arrow.clockwise") {
                            webView.layer.opacity = 0.0
                            webView.reload()
                        }
                    }
                }
        }
    }
}

struct WebViewForTower: UIViewRepresentable {

    @Binding var webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.layer.opacity = 0.0
        webView.load(URLRequest(url: towerURL))
        webView.isInspectable = true
        return webView
    }

    func makeCoordinator() -> CoordinatorForTower {
        Coordinator()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Blank function to conform to protocol
    }
}

class CoordinatorForTower: NSObject, WKNavigationDelegate {
    let cleanupTowerJS = """
\(globalJSFunctions)

\(globalCleanup)

\(iidxTowerCleanup)
"""

    let cleanupLoginJS = """
\(globalJSFunctions)

\(globalCleanup)

\(loginPageCleanup)
"""

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let webViewURL = webView.url {
            let urlString = webViewURL.absoluteString
            webView.evaluateJavaScript(self.cleanupTowerJS)
            if urlString.starts(with: towerURL.absoluteString) {
                webView.layer.opacity = 1.0
            } else {
                webView.evaluateJavaScript(self.cleanupLoginJS)
            }
        }
    }
}
