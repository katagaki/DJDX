//
//  SDVXVersion.swift
//  DJDX
//
//  Created by Claude on 2026/05/30.
//

import Foundation

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

    func loginPageRedirectURL() -> URL {
        URL(string: """
https://p.eagate.573.jp/gate/p/login.html?path=http%3A%2F%2Fp.eagate.573.jp%2Fgame%2Fsdvx%2F\(slug)%2Fplaydata%2Findex.html
""")!
    }

    func downloadPageURL() -> URL {
        URL(string: "https://p.eagate.573.jp/game/sdvx/\(slug)/playdata/index.html")!
    }

    func profilePageURL() -> URL {
        URL(string: "https://p.eagate.573.jp/game/sdvx/\(slug)/playdata/profile/index.html")!
    }
}
