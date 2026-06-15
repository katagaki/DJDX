import Foundation
import SwiftUI
import UIKit

enum DDRVersion: Int, Codable, CaseIterable {
    case world = 1

    var slug: String {
        switch self {
        case .world: "ddrworld"
        }
    }

    var marketingName: String {
        switch self {
        case .world: "DDR WORLD"
        }
    }

    static var supportedVersions: [DDRVersion] {
        [.world]
    }

    var lightModeColor: UIColor {
        switch self {
        case .world: UIColor(red: 224 / 255, green: 32 / 255, blue: 96 / 255, alpha: 1.0)
        }
    }

    var darkModeColor: UIColor {
        switch self {
        case .world: UIColor(red: 255 / 255, green: 96 / 255, blue: 160 / 255, alpha: 1.0)
        }
    }

    var color: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkModeColor : lightModeColor
        })
    }

    // The single-style score page is the post-login landing point; the scraper
    // fans out from this directory across styles and offsets.
    func loginPageRedirectURL() -> URL {
        URL(string: """
https://p.eagate.573.jp/gate/p/login.html?path=https%3A%2F%2Fp.eagate.573.jp%2Fgame%2Fddr%2F\(slug)%2Fplaydata%2Fmusic_data_single.html%3Foffset%3D0%26filter%3D0%26display%3Dscore
""")!
    }

    func scorePageURL() -> URL {
        URL(string: """
https://p.eagate.573.jp/game/ddr/\(slug)/playdata/music_data_single.html?offset=0&filter=0&display=score
""")!
    }

    func errorPageURL() -> URL {
        URL(string: "https://p.eagate.573.jp/game/ddr/\(slug)/error/")!
    }

    // BEMANIWiki 2nd DDR WORLD song lists (UTF-8 page paths). 新曲リスト covers
    // WORLD's new songs; 旧曲リスト covers every earlier version, grouped by
    // version section headers.
    func bemaniWikiNewSongsPageURL() -> URL {
        URL(string: """
https://bemaniwiki.com/?DanceDanceRevolution+WORLD/%E6%96%B0%E6%9B%B2%E3%83%AA%E3%82%B9%E3%83%88
""")!
    }

    func bemaniWikiOldSongsPageURL() -> URL {
        URL(string: """
https://bemaniwiki.com/?DanceDanceRevolution+WORLD/%E6%97%A7%E6%9B%B2%E3%83%AA%E3%82%B9%E3%83%88
""")!
    }

    static let worldVersionNumber = 20
}
