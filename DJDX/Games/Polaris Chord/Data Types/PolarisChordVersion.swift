import SwiftUI
import UIKit

enum PolarisChordVersion: Int, Codable, CaseIterable {
    case polarisChord = 1

    var slug: String {
        switch self {
        case .polarisChord: "pc"
        }
    }

    var marketingName: String {
        switch self {
        case .polarisChord: "ポラリスコード"
        }
    }

    static var supportedVersions: [PolarisChordVersion] {
        [.polarisChord]
    }

    var lightModeColor: UIColor {
        switch self {
        case .polarisChord: UIColor(red: 0 / 255, green: 150 / 255, blue: 220 / 255, alpha: 1.0)
        }
    }

    var darkModeColor: UIColor {
        switch self {
        case .polarisChord: UIColor(red: 100 / 255, green: 200 / 255, blue: 255 / 255, alpha: 1.0)
        }
    }

    var color: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkModeColor : lightModeColor
        })
    }

    func loginPageRedirectURL() -> URL {
        URL(string: "https://p.eagate.573.jp/gate/p/login.html?path=" +
            "https%3A%2F%2Fp.eagate.573.jp%2Fgame%2Fpolarischord%2F" +
            "\(slug)%2Fplaydata%2Fmusic_data.html")!
    }

    func musicDataPageURL() -> URL {
        URL(string: "https://p.eagate.573.jp/game/polarischord/\(slug)/playdata/music_data.html")!
    }

    func profilePageURL() -> URL {
        URL(string: "https://p.eagate.573.jp/game/polarischord/\(slug)/playdata/index.html")!
    }

    func playDataEndpointURL() -> URL {
        URL(string: "https://p.eagate.573.jp/game/polarischord/\(slug)/json/pdata_getdata.html")!
    }
}
