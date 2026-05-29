//
//  WebImporter.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

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

    @Environment(\.dismiss) var dismiss
    @Environment(ProgressAlertManager.self) var progressAlertManager

    @Binding var importToDate: Date
    @Binding var importMode: IIDXImportMode
    @Binding var isAutoImportFailed: Bool
    @Binding var didImportSucceed: Bool
    @Binding var autoImportFailedReason: ImportFailedReason?
    @State var observers = [NSKeyValueObservation]()

    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion

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
                let actor = DataImporter()
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

class CoordinatorForImporter: NSObject, WKNavigationDelegate {
    let cleanupJS = """
\(globalJSFunctions)

\(globalCleanup)

\(loginPageCleanup)
"""

    var delegate: UpdateScoreDataDelegate
    var importMode: IIDXImportMode
    var version: IIDXVersion

    var hasStartedExtraction: Bool = false
    var hasResolved: Bool = false
    var watchdog: Task<Void, Never>?

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
            } else if urlString.starts(with: self.version.errorPageURL().absoluteString) {
                webView.layer.opacity = 0.0
                self.resolveFailure(with: Self.failureReason(forErrorPageURL: urlString))
            } else {
                webView.layer.opacity = 1.0
            }
        }
    }

    func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        handleNavigationFailure(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        handleNavigationFailure(error)
    }

    func handleNavigationFailure(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 { return }
        resolveFailure(with: .serverError)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // Sync WebView cookie store with URLSession cookie store
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
        let buttonValue: String
        switch importMode {
        case .single: buttonValue = "SP"
        case .double: buttonValue = "DP"
        case .tower: buttonValue = "tower"
        }
        webView.callAsyncJavaScript(
            scoreDownloadFetchBody,
            arguments: ["buttonValue": buttonValue],
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

    static func failureReason(forErrorPageURL urlString: String) -> ImportFailedReason {
        if let range = urlString.range(of: "err=") {
            return failureReason(forSentinel: String(urlString[range.upperBound...]))
        }
        return .serverError
    }
}

// swiftlint:disable class_delegate_protocol
protocol UpdateScoreDataDelegate: Sendable {
    func importScoreData(using newScoreData: String) async
    func stopProcessing(with reason: ImportFailedReason)
}
// swiftlint:enable class_delegate_protocol
