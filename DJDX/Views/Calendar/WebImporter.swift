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

// swiftlint:disable line_length
let loginPageRedirectURL: URL = URL(string: """
https://p.eagate.573.jp/gate/p/login.html?path=http%3A%2F%2Fp.eagate.573.jp%2Fgame%2F2dx%2F31%2Fdjdata%2Fscore_download.html
""")!
let loginPageURL: URL = URL(string: """
https://my1.konami.net/ja/signin
""")!
let downloadPageURL: URL = URL(string: """
https://p.eagate.573.jp/game/2dx/31/djdata/score_download.html
""")!
let errorPageURL: URL = URL(string: """
https://p.eagate.573.jp/game/2dx/31/error/error.html
""")!
// swiftlint:enable line_length

struct WebImporter: View {
    @State var importMode: IIDXPlayType
    @Binding var isAutoImportFailed: Bool
    @Binding var didImportSucceed: Bool
    @Binding var autoImportFailedReason: ImportFailedReason?

    var body: some View {
        WebViewForImporter(
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

struct WebViewForImporter: UIViewRepresentable, UpdateScoreDataDelegate {

    @Environment(ProgressAlertManager.self) var progressAlertManager

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var calendar: CalendarManager

    @Binding var importMode: IIDXPlayType
    @Binding var isAutoImportFailed: Bool
    @Binding var didImportSucceed: Bool
    @Binding var autoImportFailedReason: ImportFailedReason?
    @State var observers = [NSKeyValueObservation]()

    let webView = WKWebView()

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.layer.opacity = 0.0
        webView.load(URLRequest(url: loginPageRedirectURL))
        return webView
    }

    func makeCoordinator() -> CoordinatorForImporter {
        Coordinator(updateScoreDataDelegate: self, importMode: importMode)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Blank function to conform to protocol
    }

    @MainActor
    func importScoreData(using csvString: String) async {
        progressAlertManager.show(title: "Alert.Importing.Title", message: "Alert.Importing.Text")
        Task.detached {
            await calendar.importCSV(csvString: csvString, reportingTo: progressAlertManager, for: importMode)
            await MainActor.run {
                didImportSucceed = true
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
function waitForElementToExist(selector) {
return new Promise(resolve => {
    if (document.querySelector(selector)) {
        return resolve(document.querySelector(selector))
    }
    const observer = new MutationObserver(mutations => {
        if (document.querySelector(selector)) {
            observer.disconnect()
            resolve(document.querySelector(selector))
        }
    })
    observer.observe(document.body, {
        childList: true,
        subtree: true
    })
})
}

var head = document.head || document.getElementsByTagName('head')[0]

// ダークモード
var darkModeCSS = `
@media (prefers-color-scheme: dark) {
body, #id_ea_common_content_whole {
    background-color: #000000;
    color: #ffffff;
}
header, .Header_logo__konami--default__lYPft {
    background-color: #000000!important;
}
.Form_login__layout--narrow-frame__SnckF,
.Form_login__layout--default__bEjGz,
.Form_login__form--default__3G_u1,
.Form_login__form--narrow-frame__Rvksw,
#email-form {
    border: unset;
    background-color: #1c1c1e!important;
}
.form-control, .form-control:focus {
    background-color: #000000!important;
    color: #fff!important;
}
.card {
    background-color: #1c1c1e!important;
}
}

@media (prefers-color-scheme: light) {
body {
    background-color: #ffffff;
    color: #000000;
}
}

`
var style = document.createElement('style')
style.type = 'text/css'
style.appendChild(document.createTextNode(darkModeCSS))
head.appendChild(style)

// テキスト選択を無効化
var disableSelectionCSS = '*{-webkit-touch-callout:none;-webkit-user-select:none}'
var style = document.createElement('style')
style.type = 'text/css'
style.appendChild(document.createTextNode(disableSelectionCSS))
head.appendChild(style)

// フッターを取り除く
document.body.style.setProperty('margin-bottom', '0', 'important')
waitForElementToExist('footer').then((element) => {
document.getElementsByTagName('footer')[0].remove()
})
waitForElementToExist('#synalio-iframe').then((element) => {
document.getElementById('synalio-iframe').remove()
})

// チャットポップアップを取り除く
waitForElementToExist('.fs-6').then((element) => {
document.getElementsByClassName('fs-6')[0].remove()
})

// Cookieバナーを取り除く
waitForElementToExist('#onetrust-consent-sdk').then((element) => {
document.getElementById('onetrust-consent-sdk').remove()
})
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

    var updateScoreDataDelegate: UpdateScoreDataDelegate
    var importMode: IIDXPlayType
    var waitingForDownloadPageFormSubmit: Bool = false

    init(updateScoreDataDelegate: UpdateScoreDataDelegate, importMode: IIDXPlayType = .single) {
        self.updateScoreDataDelegate = updateScoreDataDelegate
        self.importMode = importMode
        super.init()
    }

    // swiftlint:disable cyclomatic_complexity
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let webViewURL = webView.url {
            let urlString = webViewURL.absoluteString
            webView.evaluateJavaScript(self.cleanupJS)
            if urlString.starts(with: downloadPageURL.absoluteString) {
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
                                await self.updateScoreDataDelegate.importScoreData(using: result)
                            }
                        } else {
                            self.updateScoreDataDelegate.stopProcessing(with: .serverError)
                        }
                    }
                    waitingForDownloadPageFormSubmit = false
                }
            } else if urlString.starts(with: errorPageURL.absoluteString) {
                webView.layer.opacity = 0.0
                if urlString.hasSuffix("?err=1") {
                    self.updateScoreDataDelegate.stopProcessing(with: .noPremiumCourse)
                } else if urlString.hasSuffix("?err=2") {
                    self.updateScoreDataDelegate.stopProcessing(with: .noEAmusementPass)
                } else if urlString.hasSuffix("?err=3") {
                    self.updateScoreDataDelegate.stopProcessing(with: .noPlayData)
                } else if urlString.hasSuffix("?err=4") {
                    self.updateScoreDataDelegate.stopProcessing(with: .serverError)
                } else if urlString.hasSuffix("?err=5") {
                    self.updateScoreDataDelegate.stopProcessing(with: .noPremiumCourse)
                } else {
                    self.updateScoreDataDelegate.stopProcessing(with: .serverError)
                }
            } else {
                webView.layer.opacity = 1.0
            }
        }
    }
    // swiftlint:enable cyclomatic_complexity

    func evaluateIIDXSPScript(_ webView: WKWebView) {
        webView.evaluateJavaScript(self.selectSPButtonJS) { _, error in
            if error != nil {
                self.updateScoreDataDelegate.stopProcessing(with: .maintenance)
            }
        }
    }

    func evaluateIIDXDPScript(_ webView: WKWebView) {
        webView.evaluateJavaScript(self.selectDPButtonJS) { _, error in
            if error != nil {
                self.updateScoreDataDelegate.stopProcessing(with: .maintenance)
            }
        }
    }
}

// swiftlint:disable class_delegate_protocol
protocol UpdateScoreDataDelegate {
    func importScoreData(using newScoreData: String) async
    func stopProcessing(with reason: ImportFailedReason)
}
// swiftlint:enable class_delegate_protocol
