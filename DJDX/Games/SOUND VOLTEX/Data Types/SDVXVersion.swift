import Foundation
import SwiftUI
import UIKit

enum SDVXVersion: Int, Codable, CaseIterable {
    case exceedGear = 6
    case nabla = 7

    // e-amusement URL slug
    var slug: String {
        switch self {
        case .exceedGear: "vi"
        case .nabla: "vii"
        }
    }

    var marketingName: String {
        switch self {
        case .exceedGear: "EXCEED GEAR"
        case .nabla: "NABLA"
        }
    }

    static var supportedVersions: [SDVXVersion] {
        [.exceedGear, .nabla]
    }

    var lightModeColor: UIColor {
        switch self {
        case .exceedGear: return UIColor(red: 222 / 255, green: 49 / 255, blue: 124 / 255, alpha: 1.0)
        case .nabla: return UIColor(red: 124 / 255, green: 160 / 255, blue: 24 / 255, alpha: 1.0)
        }
    }

    var darkModeColor: UIColor {
        switch self {
        case .exceedGear: return UIColor(red: 255 / 255, green: 105 / 255, blue: 180 / 255, alpha: 1.0)
        case .nabla: return UIColor(red: 178 / 255, green: 222 / 255, blue: 39 / 255, alpha: 1.0)
        }
    }

    var color: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkModeColor : lightModeColor
        })
    }

    func loginPageRedirectURL() -> URL {
        URL(string: """
https://p.eagate.573.jp/gate/p/login.html?path=https%3A%2F%2Fp.eagate.573.jp%2Fgame%2Fsdvx%2F\(slug)%2Fplaydata%2Fdownload%2Findex.html%3Fmethod%3Ddisplay
""")!
    }

    func downloadPageURL() -> URL {
        URL(string: "https://p.eagate.573.jp/game/sdvx/\(slug)/playdata/download/index.html?method=display")!
    }

    func errorPageURL() -> URL {
        URL(string: "https://p.eagate.573.jp/game/sdvx/\(slug)/error/index.html")!
    }

    func profilePageURL() -> URL {
        URL(string: "https://p.eagate.573.jp/game/sdvx/\(slug)/playdata/profile/index.html")!
    }
}
