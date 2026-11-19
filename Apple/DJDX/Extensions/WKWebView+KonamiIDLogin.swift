import Foundation
import WebKit

extension WKWebView {
    func addKonamiIDLoginAutofill() {
        let email = (UserDefaults.standard.string(forKey: "Global.KonamiID.Email") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: email, options: .fragmentsAllowed),
              let emailLiteral = String(data: data, encoding: .utf8) else { return }
        configuration.userContentController.addUserScript(
            WKUserScript(source: konamiIDLoginAutofillUserScript
                .replacingOccurrences(of: "DJDX_KONAMI_ID_EMAIL", with: emailLiteral),
                         injectionTime: .atDocumentStart,
                         forMainFrameOnly: true)
        )
    }
}
