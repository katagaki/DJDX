import SwiftUI
import UIKit
import WebKit

struct IIDXWebImporter: View {
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

    var initialStyle: String {
        switch importMode {
        case .single: return "SP"
        case .double: return "DP"
        case .tower: return "tower"
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.layer.opacity = 0.0
        webView.load(URLRequest(url: iidxVersion.loginPageRedirectURL(style: initialStyle)))
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
                let actor = IIDXImporter()
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

    func importTowerData(using towerData: String) async {
        let actor = IIDXImporter()
        for await _ in await actor.importCSV(
            csv: towerData,
            to: importToDate,
            for: .tower,
            from: iidxVersion
        ) {
            // Drains the import progress stream; no per-update handling needed
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
    weak var activeWebView: WKWebView?
    var pendingScoreCSV: String?

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

    func webView(_: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        #if DEBUG
        debugPrint("[IIDXWebImporter] navigate ->", navigationAction.request.url?.absoluteString ?? "nil")
        #endif
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        guard let webViewURL = webView.url else { return }
        let urlString = webViewURL.absoluteString
        #if DEBUG
        debugPrint("[IIDXWebImporter] didFinish ->", urlString)
        #endif
        webView.evaluateJavaScript(self.cleanupJS) { _, _ in
            if urlString.starts(with: self.version.downloadPageURL().absoluteString) {
                webView.layer.opacity = 0.0
                webView.isUserInteractionEnabled = false
                self.activeWebView = webView
                if !self.hasStartedExtraction {
                    self.hasStartedExtraction = true
                    self.startExtractionWatchdog()
                }
                // Login redirects straight to the styled URL (?style=SP|DP|tower),
                // which renders the CSV into <textarea id="score_data">; read it
                // directly. Fall back to a styled navigation if we ever land on
                // the base page without a style.
                if urlString.contains("style=") {
                    self.handleStyledPageLoaded(webView, urlString: urlString)
                } else {
                    self.loadStyledPage(webView, style: self.currentStyle)
                }
            } else if urlString.starts(with: self.version.errorPageURL().absoluteString) {
                webView.layer.opacity = 0.0
                self.resolveFailure(with: Self.failureReason(forErrorPageURL: urlString))
            } else {
                webView.layer.opacity = 1.0
            }
        }
    }

    // The style we want to load next for this page navigation.
    var currentStyle: String {
        switch importMode {
        case .single: return "SP"
        case .double: return "DP"
        case .tower: return "tower"
        }
    }

    func loadStyledPage(_ webView: WKWebView, style: String) {
        webView.load(URLRequest(url: version.downloadPageURL(style: style)))
    }

    func handleStyledPageLoaded(_ webView: WKWebView, urlString: String) {
        let isTowerStyle = urlString.contains("style=tower")
        webView.callAsyncJavaScript(
            scoreDataReadBody,
            arguments: [:],
            in: nil,
            in: .page
        ) { result in
            let value = (try? result.get()) as? String
            if isTowerStyle {
                // Tower phase (either a tower-only import or the chained tower
                // fetch after SP/DP). Import tower data if present, then resolve.
                if let towerCSV = value, !towerCSV.isEmpty, !towerCSV.hasPrefix("ERR:") {
                    Task {
                        await self.delegate.importTowerData(using: towerCSV)
                        self.resolveSuccess(with: self.pendingScoreCSV ?? towerCSV)
                    }
                } else if self.importMode == .tower {
                    self.resolveFailure(with: Self.failureReason(forSentinel:
                        (value?.hasPrefix("ERR:") ?? false) ? String(value!.dropFirst(4)) : "empty"))
                } else {
                    self.resolveSuccess(with: self.pendingScoreCSV ?? "")
                }
                return
            }
            // SP/DP score phase.
            guard let value, !value.isEmpty else {
                self.resolveFailure(with: .serverError)
                return
            }
            if value.hasPrefix("ERR:") {
                self.resolveFailure(with: Self.failureReason(forSentinel: String(value.dropFirst(4))))
                return
            }
            // Score read succeeded; chain a tower fetch in the same session.
            self.pendingScoreCSV = value
            self.startExtractionWatchdog()
            self.loadStyledPage(webView, style: "tower")
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
        #if DEBUG
        debugPrint("[IIDXWebImporter] navFail ->", nsError.domain, nsError.code, nsError.localizedDescription)
        #endif
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 { return }
        resolveFailure(with: .serverError)
    }

    func webView(_ webView: WKWebView, didCommit _: WKNavigation!) {
        // Sync WebView cookie store with URLSession cookie store
        let webViewCookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let nativeCookieStorage = HTTPCookieStorage.shared
        webViewCookieStore.getAllCookies { cookies in
            for cookie in cookies {
                nativeCookieStorage.setCookie(cookie)
            }
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
    func importTowerData(using towerData: String) async
    func stopProcessing(with reason: ImportFailedReason)
}
// swiftlint:enable class_delegate_protocol
