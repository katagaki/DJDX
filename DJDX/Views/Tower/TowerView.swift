//
//  TowerView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/06.
//

import SwiftUI
import WebKit

struct TowerView: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @State var webView = WKWebView()
    @State var isLoading: Bool = true
    @State var isTowerAvailable: Bool = true

    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    var body: some View {
        NavigationStack(path: $navigationManager[.tower]) {
            WebViewForTower(
                webView: $webView,
                isTowerAvailable: $isTowerAvailable,
                isLoading: $isLoading,
                towerURL: iidxVersion.towerURL()
            )
            .navigator("ViewTitle.Tower", inline: true)
            .toolbar {
//                ToolbarItem(placement: .topBarLeading) {
//                    Button("Shared.Import") {
//                        navigationManager.push(ViewPath.importerWebIIDXTower, for: .tower)
//                    }
//                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Shared.Refresh", systemImage: "arrow.clockwise") {
                        webView.layer.opacity = 0.0
                        isLoading = true
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
                    if isLoading {
                        VStack(spacing: 16.0) {
                            ProgressView("Shared.Loading")
                        }
                    } else {
                        Color.clear
                    }
                }
            }
            .ignoreSafeAreaConditionally()
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .importerWebIIDXTower:
                    WebImporter(importMode: .tower,
                                isAutoImportFailed: .constant(false),
                                didImportSucceed: .constant(false),
                                autoImportFailedReason: .constant(nil))
                case .importDetail(let importGroup):
                    ImportDetailView(importGroup: importGroup)
                default: Color.clear
                }
            }
        }
    }
}

struct WebViewForTower: UIViewRepresentable {

    @Binding var webView: WKWebView
    @Binding var isTowerAvailable: Bool
    @Binding var isLoading: Bool
    @State var towerURL: URL

    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.layer.opacity = 0.0
        webView.load(URLRequest(url: towerURL))
        return webView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(version: iidxVersion, updateTowerState: updateTowerState)
    }

    func updateUIView(_: WKWebView, context _: Context) {
        // Blank function to conform to protocol
    }

    func updateTowerState(_ isTowerAvailable: Bool) {
        self.isTowerAvailable = isTowerAvailable
        if isTowerAvailable {
            webView.layer.opacity = 1.0
            isLoading = false
        } else {
            webView.layer.opacity = 0.0
            isLoading = false
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
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

        init(
            version: IIDXVersion,
            updateTowerState: @escaping (Bool) -> Void
        ) {
            self.version = version
            self.updateTowerState = updateTowerState
            super.init()
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
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
}
