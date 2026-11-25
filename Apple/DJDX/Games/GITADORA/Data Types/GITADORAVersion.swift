import SwiftUI
import UIKit

enum GITADORAVersion: Int, Codable, CaseIterable {
    case galaxyWave = 1
    case galaxyWaveDelta = 2

    var slug: String {
        switch self {
        case .galaxyWave: "gitadora_galaxywave"
        case .galaxyWaveDelta: "gitadora_galaxywave_delta"
        }
    }

    var marketingName: String {
        switch self {
        case .galaxyWave: "GALAXY WAVE"
        case .galaxyWaveDelta: "GALAXY WAVE DELTA"
        }
    }

    static var supportedVersions: [GITADORAVersion] {
        [.galaxyWave, .galaxyWaveDelta]
    }

    var lightModeColor: UIColor {
        UIColor(red: 235 / 255, green: 120 / 255, blue: 20 / 255, alpha: 1.0)
    }

    var darkModeColor: UIColor {
        UIColor(red: 255 / 255, green: 150 / 255, blue: 50 / 255, alpha: 1.0)
    }

    var color: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkModeColor : lightModeColor
        })
    }

    var playDataBaseURL: String {
        "https://p.eagate.573.jp/game/gfdm/\(slug)/p/playdata/"
    }

    func loginPageRedirectURL() -> URL {
        let path = (playDataBaseURL + "profile.html")
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return URL(string: "https://p.eagate.573.jp/gate/p/login.html?path=\(path)")!
    }

    func profilePageURL() -> URL {
        URL(string: playDataBaseURL + "profile.html")!
    }

    func skillPageURL(gameType: String, skillType: Int) -> URL {
        URL(string: playDataBaseURL + "skill.html?gtype=\(gameType)&stype=\(skillType)")!
    }

    func errorPagePath() -> String {
        "/game/gfdm/\(slug)/p/error/"
    }
}
