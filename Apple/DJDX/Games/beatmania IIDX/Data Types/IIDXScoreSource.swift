import Foundation

enum IIDXScoreSource {
    case arcade(IIDXVersion)
    case infinitas

    static let infinitasDownloadPage = "https://p.eagate.573.jp/game/infinitas/2/djdata/score_download.html"

    var supportsTower: Bool {
        if case .arcade = self { return true }
        return false
    }

    func style(for importMode: IIDXImportMode) -> String {
        switch (self, importMode) {
        case (.infinitas, .double): "1"
        case (.infinitas, _): "0"
        case (.arcade, .single): "SP"
        case (.arcade, .double): "DP"
        case (.arcade, .tower): "tower"
        }
    }

    func loginPageRedirectURL(style: String) -> URL {
        switch self {
        case .arcade(let version):
            return version.loginPageRedirectURL(style: style)
        case .infinitas:
            let path = downloadPageURL(style: style).absoluteString
                .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            return URL(string: "https://p.eagate.573.jp/gate/p/login.html?path=\(path)")!
        }
    }

    func downloadPageURL() -> URL {
        switch self {
        case .arcade(let version): version.downloadPageURL()
        case .infinitas: URL(string: Self.infinitasDownloadPage)!
        }
    }

    func downloadPageURL(style: String) -> URL {
        switch self {
        case .arcade(let version): version.downloadPageURL(style: style)
        case .infinitas: URL(string: "\(Self.infinitasDownloadPage)?play_style=\(style)")!
        }
    }

    func errorPageURL() -> URL {
        switch self {
        case .arcade(let version): version.errorPageURL()
        case .infinitas: URL(string: "https://p.eagate.573.jp/game/infinitas/2/error/")!
        }
    }
}
