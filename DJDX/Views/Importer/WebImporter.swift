//
//  WebImporter.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftData
import SwiftUI
import UIKit
import WebKit

struct WebImporter: View {
    @Binding var importToDate: Date
    @State var importMode: IIDXPlayType
    @Binding var isAutoImportFailed: Bool
    @Binding var didImportSucceed: Bool
    @Binding var autoImportFailedReason: ImportFailedReason?

    var body: some View {
        WebViewForImporter(
            importToDate: $importToDate,
            importMode: $importMode,
            isAutoImportFailed: $isAutoImportFailed,
            didImportSucceed: $didImportSucceed,
            autoImportFailedReason: $autoImportFailedReason
        )
        .navigationTitle("ViewTitle.Importer.Web")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .tabBar)
        .background {
            ProgressView("Importer.Web.Loading")
        }
        .padding(0.0)
        .safeAreaInset(edge: .bottom, spacing: 0.0) {
            HStack {
                Image(systemName: "hand.raised.fill")
                Text("Importer.Web.Disclaimer")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding([.leading, .trailing], 12.0)
            .padding([.top, .bottom], 8.0)
            .background(.bar)
            .overlay(alignment: .top) {
                Rectangle()
                    .frame(height: 1/3)
                    .foregroundColor(.primary.opacity(0.2))
            }
        }
    }
}

struct WebViewForImporter: UIViewRepresentable, @preconcurrency UpdateScoreDataDelegate {

    @Environment(ProgressAlertManager.self) var progressAlertManager

    @Environment(\.modelContext) var modelContext

    @Binding var importToDate: Date
    @Binding var importMode: IIDXPlayType
    @Binding var isAutoImportFailed: Bool
    @Binding var didImportSucceed: Bool
    @Binding var autoImportFailedReason: ImportFailedReason?
    @State var observers = [NSKeyValueObservation]()

    @AppStorage(wrappedValue: IIDXVersion.pinkyCrush, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    let webView = WKWebView()

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.layer.opacity = 0.0
        webView.load(URLRequest(url: iidxVersion.loginPageRedirectURL()))
        return webView
    }

    func makeCoordinator() -> CoordinatorForImporter {
        Coordinator(delegate: self, importMode: importMode, version: iidxVersion)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Blank function to conform to protocol
    }

    func importScoreData(using csvString: String) async {
        progressAlertManager.show(
            title: "Alert.Importing.Title",
            message: "Alert.Importing.Text"
        ) {
            Task.detached {
                let actor = DataImporter(modelContainer: sharedModelContainer)
                await actor.importCSV(
                    csv: csvString,
                    to: importToDate,
                    for: importMode,
                    from: iidxVersion
                ) { currentProgress, totalProgress in
                    Task {
                        let progress = (currentProgress * 100) / totalProgress
                        await MainActor.run {
                            progressAlertManager.updateProgress(
                                progress
                            )
                        }
                    }
                }
                await MainActor.run {
                    didImportSucceed = true
                    progressAlertManager.hide()
                }
            }
        }
    }

    func stopProcessing(with reason: ImportFailedReason) {
        autoImportFailedReason = reason
        isAutoImportFailed = true
    }
}

class CoordinatorForImporter: NSObject, WKNavigationDelegate {
    let cleanupJS = """
\(globalJSFunctions)

\(globalCleanup)

\(loginPageCleanup)
"""

    let selectSPButtonJS = """
var submitButtons = document.getElementsByClassName('submit_btn')
if (submitButtons.length > 0) {
    Array.from(submitButtons).forEach(button => {
        if (button.value === "SP") {
            button.click()
        }
    })
} else {
    throw 1
}
"""

    let selectDPButtonJS = """
var submitButtons = document.getElementsByClassName('submit_btn')
if (submitButtons.length > 0) {
    Array.from(submitButtons).forEach(button => {
        if (button.value === "DP") {
            button.click()
        }
    })
} else {
    throw 1
}
"""

    let getScoreDataJS = """
document.getElementById('score_data').value
"""

    var delegate: UpdateScoreDataDelegate
    var importMode: IIDXPlayType
    var version: IIDXVersion

    var waitingForDownloadPageFormSubmit: Bool = false

    init(
        delegate: UpdateScoreDataDelegate,
        importMode: IIDXPlayType = .single,
        version: IIDXVersion
    ) {
        self.delegate = delegate
        self.importMode = importMode
        self.version = version
        super.init()
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let webViewURL = webView.url {
            let urlString = webViewURL.absoluteString
            webView.evaluateJavaScript(self.cleanupJS)
            if urlString.starts(with: version.downloadPageURL().absoluteString) {
                webView.layer.opacity = 0.0
                webView.isUserInteractionEnabled = false
                if !waitingForDownloadPageFormSubmit {
                    switch importMode {
                    case .single: evaluateIIDXSPScript(webView)
                    case .double: evaluateIIDXDPScript(webView)
                    }
                    waitingForDownloadPageFormSubmit = true
                } else {
                    webView.evaluateJavaScript(getScoreDataJS) { result, _ in
                        if let result: String = result as? String {
                            Task {
                                await self.delegate.importScoreData(using: result)
                            }
                        } else {
                            Task {
                                await MainActor.run {
                                    self.delegate.stopProcessing(with: .serverError)
                                }
                            }
                        }
                    }
                    waitingForDownloadPageFormSubmit = false
                }
            } else if urlString.starts(with: version.errorPageURL().absoluteString) {
                webView.layer.opacity = 0.0
                Task { [urlString] in
                    await MainActor.run {
                        if urlString.hasSuffix("?err=1") {
                            self.delegate.stopProcessing(with: .noPremiumCourse)
                        } else if urlString.hasSuffix("?err=2") {
                            self.delegate.stopProcessing(with: .noEAmusementPass)
                        } else if urlString.hasSuffix("?err=3") {
                            self.delegate.stopProcessing(with: .noPlayData)
                        } else if urlString.hasSuffix("?err=4") {
                            self.delegate.stopProcessing(with: .serverError)
                        } else if urlString.hasSuffix("?err=5") {
                            self.delegate.stopProcessing(with: .noPremiumCourse)
                        } else {
                            self.delegate.stopProcessing(with: .serverError)
                        }
                    }
                }
            } else {
                webView.layer.opacity = 1.0
            }
        }
    }

    func evaluateIIDXSPScript(_ webView: WKWebView) {
        webView.evaluateJavaScript(self.selectSPButtonJS) { _, error in
            if error != nil {
                self.delegate.stopProcessing(with: .maintenance)
            }
        }
    }

    func evaluateIIDXDPScript(_ webView: WKWebView) {
        webView.evaluateJavaScript(self.selectDPButtonJS) { _, error in
            if error != nil {
                self.delegate.stopProcessing(with: .maintenance)
            }
        }
    }
}

// swiftlint:disable class_delegate_protocol
protocol UpdateScoreDataDelegate: Sendable {
    func importScoreData(using newScoreData: String) async
    func stopProcessing(with reason: ImportFailedReason)
}
// swiftlint:enable class_delegate_protocol
