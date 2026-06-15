import SwiftUI
import UIKit
import WebKit

struct DDRWebImporter: View {
    @Binding var importToDate: Date
    @Binding var isAutoImportFailed: Bool
    @Binding var didImportSucceed: Bool
    @Binding var autoImportFailedReason: ImportFailedReason?

    var body: some View {
        DDRWebViewForImporter(
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

struct DDRWebViewForImporter: UIViewRepresentable, @preconcurrency DDRUpdateScoreDataDelegate {

    @Environment(\.dismiss) var dismiss
    @Environment(ProgressReporter.self) var progressReporter

    @Binding var importToDate: Date
    @Binding var isAutoImportFailed: Bool
    @Binding var didImportSucceed: Bool
    @Binding var autoImportFailedReason: ImportFailedReason?

    @AppStorage(wrappedValue: DDRVersion.world, "Global.DDR.Version") var ddrVersion: DDRVersion

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
        webView.load(URLRequest(url: ddrVersion.loginPageRedirectURL()))
        #if DEBUG
        webView.isInspectable = true
        #endif
        return webView
    }

    func makeCoordinator() -> DDRCoordinatorForImporter {
        DDRCoordinatorForImporter(delegate: self, version: ddrVersion)
    }

    func updateUIView(_: WKWebView, context _: Context) {
    }

    func importScoreData(using jsonString: String) async {
        progressReporter.show(
            title: "Alert.Importing.Title",
            message: "Alert.Importing.Text"
        )
        let importer = DDRImporter()
        for await progress in await importer.importJSON(
            json: jsonString,
            to: importToDate,
            version: ddrVersion
        ) {
            if let currentFileProgress = progress.currentFileProgress,
               let currentFileTotal = progress.currentFileTotal,
               currentFileTotal > 0 {
                let percentage = (currentFileProgress * 100) / currentFileTotal
                await MainActor.run {
                    progressReporter.updateProgress(percentage)
                }
            }
        }
        await MainActor.run {
            dismiss()
            progressReporter.hide()
            didImportSucceed = true
        }
    }

    func stopProcessing(with reason: ImportFailedReason) {
        dismiss()
        autoImportFailedReason = reason
        isAutoImportFailed = true
    }
}

class DDRCoordinatorForImporter: NSObject, WKNavigationDelegate {
    let cleanupJS = """
\(globalJSFunctions)

\(globalCleanup)

\(loginPageCleanup)
"""

    var delegate: DDRUpdateScoreDataDelegate
    var version: DDRVersion

    var hasStartedExtraction: Bool = false
    var hasResolved: Bool = false
    var watchdog: Task<Void, Never>?

    init(delegate: DDRUpdateScoreDataDelegate, version: DDRVersion) {
        self.delegate = delegate
        self.version = version
        super.init()
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        guard let webViewURL = webView.url else { return }
        let urlString = webViewURL.absoluteString
        webView.evaluateJavaScript(self.cleanupJS) { _, _ in
            if urlString.contains("/playdata/music_data_single.html") {
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
            ddrScoreDataFetchBody,
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
        debugPrint("[DDRImport] extraction result length:", value?.count ?? -1,
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

    func resolveSuccess(with jsonString: String) {
        guard !hasResolved else { return }
        hasResolved = true
        watchdog?.cancel()
        Task { await self.delegate.importScoreData(using: jsonString) }
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
            try? await Task.sleep(for: .seconds(120))
            if Task.isCancelled { return }
            await MainActor.run {
                self?.resolveFailure(with: .serverError)
            }
        }
    }

    static func failureReason(forSentinel sentinel: String) -> ImportFailedReason {
        switch sentinel {
        case "1": return .noPremiumCourse
        case "3": return .noEAmusementPass
        case "4", "empty": return .noPlayData
        case "maintenance": return .maintenance
        default: return .serverError
        }
    }

    static func failureReason(forErrorPageURL urlString: String) -> ImportFailedReason {
        if let range = urlString.range(of: "err=") {
            let remainder = urlString[range.upperBound...]
            let code = remainder.prefix { $0 != "&" }
            return failureReason(forSentinel: String(code))
        }
        return .serverError
    }
}

// swiftlint:disable class_delegate_protocol
protocol DDRUpdateScoreDataDelegate: Sendable {
    func importScoreData(using newScoreData: String) async
    func stopProcessing(with reason: ImportFailedReason)
}
// swiftlint:enable class_delegate_protocol
