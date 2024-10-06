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
    @State var isTowerAvailable: Bool = true

    @AppStorage(wrappedValue: IIDXVersion.pinkyCrush, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    var body: some View {
        NavigationStack {
            WebViewForTower(
                webView: $webView,
                isTowerAvailable: $isTowerAvailable,
                towerURL: iidxVersion.towerURL()
            )
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
                            webView.load(URLRequest(url: iidxVersion.towerURL()))
                        }
                    }
                }
                .background {
                    if !isTowerAvailable {
                        ContentUnavailableView(
                            "Tower.Unavailable.Title",
                            systemImage: "exclamationmark.circle.fill",
                            description: Text("Tower.Unavailable.Description")
                        )
                    } else {
                        Color.clear
                    }
                }
        }
    }
}

struct WebViewForTower: UIViewRepresentable {

    @Binding var webView: WKWebView
    @Binding var isTowerAvailable: Bool
    @State var towerURL: URL

    @AppStorage(wrappedValue: IIDXVersion.pinkyCrush, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.layer.opacity = 0.0
        webView.load(URLRequest(url: towerURL))
        return webView
    }

    func makeCoordinator() -> CoordinatorForTower {
        Coordinator(version: iidxVersion, updateTowerState: updateTowerState)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Blank function to conform to protocol
    }

    func updateTowerState(_ isTowerAvailable: Bool) {
        self.isTowerAvailable = isTowerAvailable
        if isTowerAvailable {
            webView.layer.opacity = 1.0
        } else {
            webView.layer.opacity = 0.0
        }
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

    var version: IIDXVersion
    var updateTowerState: (Bool) -> Void

    init(version: IIDXVersion, updateTowerState: @escaping (Bool) -> Void) {
        self.version = version
        self.updateTowerState = updateTowerState
        super.init()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let webViewURL = webView.url {
            let urlString = webViewURL.absoluteString
            webView.evaluateJavaScript(self.cleanupTowerJS) { _, _ in
                if urlString.starts(with: self.version.towerURL().absoluteString) {
                    webView.evaluateJavaScript("document.documentElement.outerHTML.toString()") { html, _ in
                        if let html = html as? String {
                            self.updateTowerState(!html.contains("Http 404"))
                        } else {
                            self.updateTowerState(false)
                        }
                    }
                } else {
                    webView.evaluateJavaScript(self.cleanupLoginJS) { _, _ in
                        webView.layer.opacity = 1.0
                    }
                }
            }
        }
    }
}
