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
    @State var importMode: IIDXImportMode
    @Binding var isAutoImportFailed: Bool
    @Binding var didImportSucceed: Bool
    @Binding var autoImportFailedReason: ImportFailedReason?

    init(
        importToDate: Binding<Date> = .constant(Date()),
        importMode: IIDXImportMode,
        isAutoImportFailed: Binding<Bool>,
        didImportSucceed: Binding<Bool>,
        autoImportFailedReason: Binding<ImportFailedReason?>
    ) {
        self._importToDate = importToDate
        self._importMode = State(initialValue: importMode)
        self._isAutoImportFailed = isAutoImportFailed
        self._didImportSucceed = didImportSucceed
        self._autoImportFailedReason = autoImportFailedReason
    }

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
            ProgressView("Shared.Loading")
        }
        .padding(0.0)
    }
}

struct WebViewForImporter: UIViewRepresentable, @preconcurrency UpdateScoreDataDelegate {

    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(ProgressAlertManager.self) var progressAlertManager

    @Environment(\.modelContext) var modelContext

    @Binding var importToDate: Date
    @Binding var importMode: IIDXImportMode
    @Binding var isAutoImportFailed: Bool
    @Binding var didImportSucceed: Bool
    @Binding var autoImportFailedReason: ImportFailedReason?
    @State var observers = [NSKeyValueObservation]()

    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    let webView = WKWebView()

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.layer.opacity = 0.0
        webView.load(URLRequest(url: iidxVersion.loginPageRedirectURL()))
        #if DEBUG
        webView.isInspectable = true
        #endif
        return webView
    }

    func makeCoordinator() -> CoordinatorForImporter {
        Coordinator(delegate: self, importMode: importMode, version: iidxVersion)
    }

    func updateUIView(_: WKWebView, context _: Context) {
        // Blank function to conform to protocol
    }

    func importScoreData(using csvString: String) async {
        progressAlertManager.show(
            title: "Alert.Importing.Title",
            message: "Alert.Importing.Text"
        ) {
            Task {
                let actor = DataImporter(modelContainer: sharedModelContainer)
                for await progress in await actor.importCSV(
                    csv: csvString,
                    to: importToDate,
                    for: importMode,
                    from: iidxVersion
                ) {
                    if let currentFileProgress = progress.currentFileProgress,
                        let currentFileTotal = progress.currentFileTotal {
                        let progress = (currentFileProgress * 100) / currentFileTotal
                        await MainActor.run {
                            progressAlertManager.updateProgress(progress)
                        }
                    }
                }
                await MainActor.run {
                    // HACK: View doesn't dismiss on iOS 26, need to improve the way this is handled
                    navigationManager.popToRoot(for: .imports)
                    progressAlertManager.hide()
                    didImportSucceed = true
                }
            }
        }
    }

    func stopProcessing(with reason: ImportFailedReason) {
        // HACK: View doesn't dismiss on iOS 26, need to improve the way this is handled
        navigationManager.popToRoot(for: .imports)
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

    let selectTowerButtonJS = """
var submitButtons = document.getElementsByClassName('submit_btn')
if (submitButtons.length > 0) {
    Array.from(submitButtons).forEach(button => {
        if (button.value === "tower") {
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
    var importMode: IIDXImportMode
    var version: IIDXVersion

    var waitingForDownloadPageFormSubmit: Bool = false

    init(
        delegate: UpdateScoreDataDelegate,
        importMode: IIDXImportMode = .single,
        version: IIDXVersion
    ) {
        self.delegate = delegate
        self.importMode = importMode
        self.version = version
        super.init()
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        if let webViewURL = webView.url {
            let urlString = webViewURL.absoluteString
            webView.evaluateJavaScript(self.cleanupJS) { _, _ in
                if urlString.starts(with: self.version.downloadPageURL().absoluteString) {
                    webView.layer.opacity = 0.0
                    webView.isUserInteractionEnabled = false
                    if !self.waitingForDownloadPageFormSubmit {
                        switch self.importMode {
                        case .single: self.evaluateIIDXSPScript(webView)
                        case .double: self.evaluateIIDXDPScript(webView)
                        case .tower: self.evaluateTowerScript(webView)
                        }
                        self.waitingForDownloadPageFormSubmit = true
                    } else {
                        webView.evaluateJavaScript(self.getScoreDataJS) { result, _ in
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
                        self.waitingForDownloadPageFormSubmit = false
                    }
                } else if urlString.starts(with: self.version.errorPageURL().absoluteString) {
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

    func evaluateTowerScript(_ webView: WKWebView) {
        webView.evaluateJavaScript(self.selectTowerButtonJS) { _, error in
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
