//
//  WebView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/12.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let songTitle: String
    let level: IIDXLevel
    let playSide: TextagePlaySide

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.scrollView.minimumZoomScale = 5.0
        webView.scrollView.maximumZoomScale = 10.0
        if let url = textageURL() {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
    }

    func textageURL() -> URL? {
        guard let baseVersionForURL = IIDXVersion
            .latestAvailableVersionForTextage.getVersionStringForTextageURL() else {
            return nil
        }
        let songTitleForURL = songTitle
            .replacingOccurrences(of: " (LEGGENDARIA)", with: "")
            /*FOR SP/DP*/
        let encodedSongTitle = songTitleForURL.data(using: .shiftJIS)?
            .map { String(format: "%02hhx", $0) }.joined()
        guard let encodedSongTitle else {
            return nil
        }
        let urlString = "https://textage.cc/score/"
        switch playSide {
        case .single:
            return URL(string: urlString + "start=1&nm=" + encodedSongTitle + "&lv=" + baseVersionForURL)
        case .double:
            return URL(string: urlString + "start=1&nm=" + encodedSongTitle + "&lv=" + baseVersionForURL)
        }
    }

    // Re-apply the zoom once content has laid out. On iOS 18, zoom scales set
    // before the page loads do not take effect, leaving the chart unusable.
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            webView.scrollView.minimumZoomScale = 5.0
            webView.scrollView.maximumZoomScale = 10.0
            webView.scrollView.setZoomScale(5.0, animated: false)
        }
    }
}
