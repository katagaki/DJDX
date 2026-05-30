//
//  SDVXWebImporter.swift
//  DJDX
//
//  Created by Claude on 2026/05/30.
//

import SwiftUI
import UIKit
import WebKit

struct SDVXWebImporter: View {
    @Binding var importToDate: Date
    @Binding var isAutoImportFailed: Bool
    @Binding var didImportSucceed: Bool
    @Binding var autoImportFailedReason: ImportFailedReason?

    var body: some View {
        SDVXWebViewForImporter(
            importToDate: $importToDate,
            isAutoImportFailed: $isAutoImportFailed,
            didImportSucceed: $didImportSucceed,
            autoImportFailedReason: $autoImportFailedReason
        )
        .navigationTitle("ViewTitle.Importer.Web")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .background {
            ProgressView("Shared.Loading")
        }
        .padding(0.0)
    }
}

struct SDVXWebViewForImporter: UIViewRepresentable, @preconcurrency SDVXUpdateScoreDataDelegate {

    @Environment(\.dismiss) var dismiss
    @Environment(ProgressAlertManager.self) var progressAlertManager

    @Binding var importToDate: Date
    @Binding var isAutoImportFailed: Bool
    @Binding var didImportSucceed: Bool
    @Binding var autoImportFailedReason: ImportFailedReason?

    @AppStorage(wrappedValue: SDVXVersion.nabla, "Global.SDVX.Version") var sdvxVersion: SDVXVersion

    let webView: WKWebView = {
        let contentController = WKUserContentController()
        contentController.addUserScript(
            WKUserScript(source: loginPageDarkModeUserScript,
                         injectionTime: .atDocumentStart,
                         forMainFrameOnly: false)
        )
        contentController.addUserScript(
            WKUserScript(source: otpAutofillUserScript,
                         injectionTime: .atDocumentStart,
                         forMainFrameOnly: false)
        )
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        return WKWebView(frame: .zero, configuration: configuration)
    }()

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.layer.opacity = 0.0
        webView.load(URLRequest(url: sdvxVersion.loginPageRedirectURL()))
        #if DEBUG
        webView.isInspectable = true
        #endif
        return webView
    }

    func makeCoordinator() -> SDVXCoordinatorForImporter {
        SDVXCoordinatorForImporter(delegate: self, version: sdvxVersion)
    }

    func updateUIView(_: WKWebView, context _: Context) {
        // No dynamic updates needed; the web view is configured once in makeUIView
    }

    func importScoreData(using csvString: String) async {
        progressAlertManager.show(
            title: "Alert.Importing.Title",
            message: "Alert.Importing.Text"
        ) {
            Task {
                let importer = SDVXDataImporter()
                for await progress in await importer.importCSV(
                    csv: csvString,
                    to: importToDate,
                    version: sdvxVersion
                ) {
                    if let currentFileProgress = progress.currentFileProgress,
                       let currentFileTotal = progress.currentFileTotal,
                       currentFileTotal > 0 {
                        let percentage = (currentFileProgress * 100) / currentFileTotal
                        await MainActor.run {
                            progressAlertManager.updateProgress(percentage)
                        }
                    }
                }
                await MainActor.run {
                    dismiss()
                    progressAlertManager.hide()
                    didImportSucceed = true
                }
            }
        }
    }

    func stopProcessing(with reason: ImportFailedReason) {
        dismiss()
        autoImportFailedReason = reason
        isAutoImportFailed = true
    }
}

class SDVXCoordinatorForImporter: NSObject, WKNavigationDelegate {
    let cleanupJS = """
\(globalJSFunctions)

\(globalCleanup)

\(loginPageCleanup)
"""

    var delegate: SDVXUpdateScoreDataDelegate
    var version: SDVXVersion

    var hasStartedExtraction: Bool = false
    var hasResolved: Bool = false
    var watchdog: Task<Void, Never>?

    init(delegate: SDVXUpdateScoreDataDelegate, version: SDVXVersion) {
        self.delegate = delegate
        self.version = version
        super.init()
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        guard let webViewURL = webView.url else { return }
        let urlString = webViewURL.absoluteString
        webView.evaluateJavaScript(self.cleanupJS) { _, _ in
            if urlString.starts(with: self.version.downloadPageURL().absoluteString) {
                webView.layer.opacity = 0.0
                webView.isUserInteractionEnabled = false
                guard !self.hasStartedExtraction else { return }
                self.hasStartedExtraction = true
                self.extractScoreData(from: webView)
            } else {
                webView.layer.opacity = 1.0
            }
        }
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        handleNavigationFailure(error)
    }

    func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        handleNavigationFailure(error)
    }

    func handleNavigationFailure(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 { return }
        resolveFailure(with: .serverError)
    }

    func webView(_ webView: WKWebView, didCommit _: WKNavigation!) {
        let webViewCookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let nativeCookieStorage = HTTPCookieStorage.shared
        webViewCookieStore.getAllCookies { cookies in
            for cookie in cookies {
                nativeCookieStorage.setCookie(cookie)
            }
        }
    }

    func extractScoreData(from webView: WKWebView) {
        startExtractionWatchdog()
        webView.callAsyncJavaScript(
            sdvxScoreDownloadFetchBody,
            arguments: [:],
            in: nil,
            in: .page
        ) { result in
            switch result {
            case .success(let value): self.handleExtractionResult(value as? String)
            case .failure: self.resolveFailure(with: .serverError)
            }
        }
    }

    func handleExtractionResult(_ value: String?) {
        #if DEBUG
        debugPrint("[SDVXImport] extraction result length:", value?.count ?? -1,
                   "prefix:", value?.prefix(40) ?? "<nil>")
        #endif
        guard let value, !value.isEmpty else {
            resolveFailure(with: .serverError)
            return
        }
        if value.hasPrefix("ERR:") {
            resolveFailure(with: Self.failureReason(forSentinel: String(value.dropFirst(4))))
        } else {
            resolveSuccess(with: value)
        }
    }

    func resolveSuccess(with csvString: String) {
        guard !hasResolved else { return }
        hasResolved = true
        watchdog?.cancel()
        Task { await self.delegate.importScoreData(using: csvString) }
    }

    func resolveFailure(with reason: ImportFailedReason) {
        guard !hasResolved else { return }
        hasResolved = true
        watchdog?.cancel()
        Task { await MainActor.run { self.delegate.stopProcessing(with: reason) } }
    }

    func startExtractionWatchdog() {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(25))
            if Task.isCancelled { return }
            await MainActor.run {
                self?.resolveFailure(with: .serverError)
            }
        }
    }

    static func failureReason(forSentinel sentinel: String) -> ImportFailedReason {
        switch sentinel {
        case "1", "5": return .noPremiumCourse
        case "2": return .noEAmusementPass
        case "3": return .noPlayData
        case "maintenance": return .maintenance
        default: return .serverError
        }
    }
}

// swiftlint:disable class_delegate_protocol
protocol SDVXUpdateScoreDataDelegate: Sendable {
    func importScoreData(using newScoreData: String) async
    func stopProcessing(with reason: ImportFailedReason)
}
// swiftlint:enable class_delegate_protocol
