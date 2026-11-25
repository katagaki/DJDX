import SwiftUI
import UIKit

enum PopnVersion: Int, Codable, CaseIterable {
    case jamFizz = 28
    case highCheers = 29

    var slug: String {
        switch self {
        case .jamFizz: "jamfizz"
        case .highCheers: "popn29"
        }
    }

    var marketingName: String {
        switch self {
        case .jamFizz: "Jam&Fizz"
        case .highCheers: "High Cheers!!"
        }
    }

    static var supportedVersions: [PopnVersion] {
        [.highCheers, .jamFizz]
    }

    var allVersionsFilterValue: String {
        switch self {
        case .jamFizz: "0"
        case .highCheers: "-1"
        }
    }

    var lightModeColor: UIColor {
        switch self {
        case .jamFizz: UIColor(red: 235 / 255, green: 80 / 255, blue: 140 / 255, alpha: 1.0)
        case .highCheers: UIColor(red: 245 / 255, green: 150 / 255, blue: 20 / 255, alpha: 1.0)
        }
    }

    var darkModeColor: UIColor {
        switch self {
        case .jamFizz: UIColor(red: 255 / 255, green: 120 / 255, blue: 170 / 255, alpha: 1.0)
        case .highCheers: UIColor(red: 255 / 255, green: 190 / 255, blue: 60 / 255, alpha: 1.0)
        }
    }

    var color: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkModeColor : lightModeColor
        })
    }

    var basePath: String {
        "/game/popn/\(slug)"
    }

    func loginPageRedirectURL() -> URL {
        let path = profilePageURL().absoluteString
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(.init(charactersIn: ".-_"))) ?? ""
        return URL(string: "https://p.eagate.573.jp/gate/p/login.html?path=\(path)")!
    }

    func profilePageURL() -> URL {
        URL(string: "https://p.eagate.573.jp\(basePath)/playdata/index.html")!
    }

    func errorPagePrefix() -> String {
        "https://p.eagate.573.jp\(basePath)/error/"
    }
}
