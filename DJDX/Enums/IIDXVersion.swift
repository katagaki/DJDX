//
//  IIDXVersion.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/05.
//

import UIKit

enum IIDXVersion: Int, Codable, CaseIterable {
    case iidx1stStyle = 1
    case iidx2ndStyle = 2
    case iidx3rdStyle = 3
    case iidx4thStyle = 4
    case iidx5thStyle = 5
    case iidx6thStyle = 6
    case iidx7thStyle = 7
    case iidx8thStyle = 8
    case iidx9thStyle = 9
    case iidx10thStyle = 10
    case red = 11
    case happySky = 12
    case distorteD = 13
    case gold = 14
    case djTroopers = 15
    case empress = 16
    case sirius = 17
    case resortAnthem = 18
    case lincle = 19
    case tricoro = 20
    case spada = 21
    case pendual = 22
    case copula = 23
    case sinobuz = 24
    case cannonBallers = 25
    case rootage = 26
    case heroicVerse = 27
    case bistrover = 28
    case castHour = 29
    case resident = 30
    case epolis = 31
    case pinkyCrush = 32

    static var supportedVersions: [IIDXVersion] {
        [.epolis, .pinkyCrush]
    }

    var marketingName: String {
        switch self {
        case .iidx1stStyle: return "1st style"
        case .iidx2ndStyle: return "2nd style"
        case .iidx3rdStyle: return "3rd style"
        case .iidx4thStyle: return "4th style"
        case .iidx5thStyle: return "5th style"
        case .iidx6thStyle: return "6th style"
        case .iidx7thStyle: return "7th style"
        case .iidx8thStyle: return "8th style"
        case .iidx9thStyle: return "9th style"
        case .iidx10thStyle: return "10th style"
        case .red: return "IIDX RED"
        case .happySky: return "HAPPY SKY"
        case .distorteD: return "DistorteD"
        case .gold: return "GOLD"
        case .djTroopers: return "DJ TROOPERS"
        case .empress: return "EMPRESS"
        case .sirius: return "SIRIUS"
        case .resortAnthem: return "Resort Anthem"
        case .lincle: return "Lincle"
        case .tricoro: return "tricoro"
        case .spada: return "SPADA"
        case .pendual: return "PENDUAL"
        case .copula: return "copula"
        case .sinobuz: return "SINOBUZ"
        case .cannonBallers: return "CANNON BALLERS"
        case .rootage: return "Rootage"
        case .heroicVerse: return "HEROIC VERSE"
        case .bistrover: return "BISTROVER"
        case .castHour: return "CastHour"
        case .resident: return "RESIDENT"
        case .epolis: return "EPOLIS"
        case .pinkyCrush: return "Pinky Crush"
        }
    }

    var lightModeColor: UIColor {
        switch self {
        case .iidx1stStyle: return UIColor(red: 0 / 255, green: 0 / 255, blue: 0 / 255, alpha: 1.0)
        case .iidx2ndStyle: return UIColor(red: 254 / 255, green: 209 / 255, blue: 83 / 255, alpha: 1.0)
        case .iidx3rdStyle: return UIColor(red: 235 / 255, green: 3 / 255, blue: 137 / 255, alpha: 1.0)
        case .iidx4thStyle: return UIColor(red: 232 / 255, green: 22 / 255, blue: 30 / 255, alpha: 1.0)
        case .iidx5thStyle: return UIColor(red: 19 / 255, green: 56 / 255, blue: 145 / 255, alpha: 1.0)
        case .iidx6thStyle: return UIColor(red: 180 / 255, green: 3 / 255, blue: 143 / 255, alpha: 1.0)
        case .iidx7thStyle: return UIColor(red: 36 / 255, green: 41 / 255, blue: 44 / 255, alpha: 1.0)
        case .iidx8thStyle: return UIColor(red: 238 / 255, green: 127 / 255, blue: 2 / 255, alpha: 1.0)
        case .iidx9thStyle: return UIColor(red: 35 / 255, green: 24 / 255, blue: 22 / 255, alpha: 1.0)
        case .iidx10thStyle: return UIColor(red: 8 / 255, green: 34 / 255, blue: 88 / 255, alpha: 1.0)
        case .red: return UIColor(red: 255 / 255, green: 0 / 255, blue: 0 / 255, alpha: 1.0)
        case .happySky: return UIColor(red: 18 / 255, green: 34 / 255, blue: 116 / 255, alpha: 1.0)
        case .distorteD: return UIColor(red: 53 / 255, green: 59 / 255, blue: 27 / 255, alpha: 1.0)
        case .gold: return UIColor(red: 191 / 255, green: 145 / 255, blue: 39 / 255, alpha: 1.0)
        case .djTroopers: return UIColor(red: 135 / 255, green: 70 / 255, blue: 38 / 255, alpha: 1.0)
        case .empress: return UIColor(red: 187 / 255, green: 7 / 255, blue: 54 / 255, alpha: 1.0)
        case .sirius: return UIColor(red: 11 / 255, green: 20 / 255, blue: 89 / 255, alpha: 1.0)
        case .resortAnthem: return UIColor(red: 216 / 255, green: 25 / 255, blue: 5 / 255, alpha: 1.0)
        case .lincle: return UIColor(red: 0 / 255, green: 176 / 255, blue: 235 / 255, alpha: 1.0)
        case .tricoro: return UIColor(red: 0 / 255, green: 68 / 255, blue: 149 / 255, alpha: 1.0)
        case .spada: return UIColor(red: 234 / 255, green: 87 / 255, blue: 29 / 255, alpha: 1.0)
        case .pendual: return UIColor(red: 86 / 255, green: 16 / 255, blue: 38 / 255, alpha: 1.0)
        case .copula: return UIColor(red: 250 / 255, green: 162 / 255, blue: 4 / 255, alpha: 1.0)
        case .sinobuz: return UIColor(red: 24 / 255, green: 37 / 255, blue: 46 / 255, alpha: 1.0)
        case .cannonBallers: return UIColor(red: 0 / 255, green: 134 / 255, blue: 67 / 255, alpha: 1.0)
        case .rootage: return UIColor(red: 93 / 255, green: 21 / 255, blue: 0 / 255, alpha: 1.0)
        case .heroicVerse: return UIColor(red: 80 / 255, green: 55 / 255, blue: 201 / 255, alpha: 1.0)
        case .bistrover: return UIColor(red: 4 / 255, green: 33 / 255, blue: 146 / 255, alpha: 1.0)
        case .castHour: return UIColor(red: 239 / 255, green: 64 / 255, blue: 3 / 255, alpha: 1.0)
        case .resident: return UIColor(red: 0 / 255, green: 33 / 255, blue: 41 / 255, alpha: 1.0)
        case .epolis: return UIColor(red: 50 / 255, green: 50 / 255, blue: 50 / 255, alpha: 1.0)
        case .pinkyCrush: return UIColor(red: 249 / 255, green: 87 / 255, blue: 142 / 255, alpha: 1.0)
        }
    }

    var darkModeColor: UIColor {
        switch self {
        case .iidx1stStyle: return UIColor(red: 200 / 255, green: 200 / 255, blue: 200 / 255, alpha: 1.0)
        case .iidx2ndStyle: return UIColor(red: 254 / 255, green: 209 / 255, blue: 83 / 255, alpha: 1.0)
        case .iidx3rdStyle: return UIColor(red: 246 / 255, green: 151 / 255, blue: 209 / 255, alpha: 1.0)
        case .iidx4thStyle: return UIColor(red: 213 / 255, green: 57 / 255, blue: 33 / 255, alpha: 1.0)
        case .iidx5thStyle: return UIColor(red: 254 / 255, green: 145 / 255, blue: 20 / 255, alpha: 1.0)
        case .iidx6thStyle: return UIColor(red: 151 / 255, green: 141 / 255, blue: 190 / 255, alpha: 1.0)
        case .iidx7thStyle: return UIColor(red: 146 / 255, green: 164 / 255, blue: 174 / 255, alpha: 1.0)
        case .iidx8thStyle: return UIColor(red: 243 / 255, green: 129 / 255, blue: 15 / 255, alpha: 1.0)
        case .iidx9thStyle: return UIColor(red: 148 / 255, green: 200 / 255, blue: 244 / 255, alpha: 1.0)
        case .iidx10thStyle: return UIColor(red: 255 / 255, green: 27 / 255, blue: 0 / 255, alpha: 1.0)
        case .red: return UIColor(red: 255 / 255, green: 0 / 255, blue: 0 / 255, alpha: 1.0)
        case .happySky: return UIColor(red: 90 / 255, green: 229 / 255, blue: 250 / 255, alpha: 1.0)
        case .distorteD: return UIColor(red: 239 / 255, green: 241 / 255, blue: 54 / 255, alpha: 1.0)
        case .gold: return UIColor(red: 202 / 255, green: 162 / 255, blue: 48 / 255, alpha: 1.0)
        case .djTroopers: return UIColor(red: 185 / 255, green: 121 / 255, blue: 88 / 255, alpha: 1.0)
        case .empress: return UIColor(red: 251 / 255, green: 33 / 255, blue: 138 / 255, alpha: 1.0)
        case .sirius: return UIColor(red: 149 / 255, green: 228 / 255, blue: 245 / 255, alpha: 1.0)
        case .resortAnthem: return UIColor(red: 252 / 255, green: 241 / 255, blue: 0 / 255, alpha: 1.0)
        case .lincle: return UIColor(red: 89 / 255, green: 196 / 255, blue: 242 / 255, alpha: 1.0)
        case .tricoro: return UIColor(red: 254 / 255, green: 247 / 255, blue: 113 / 255, alpha: 1.0)
        case .spada: return UIColor(red: 251 / 255, green: 119 / 255, blue: 55 / 255, alpha: 1.0)
        case .pendual: return UIColor(red: 243 / 255, green: 95 / 255, blue: 164 / 255, alpha: 1.0)
        case .copula: return UIColor(red: 254 / 255, green: 232 / 255, blue: 68 / 255, alpha: 1.0)
        case .sinobuz: return UIColor(red: 109 / 255, green: 134 / 255, blue: 152 / 255, alpha: 1.0)
        case .cannonBallers: return UIColor(red: 0 / 255, green: 195 / 255, blue: 100 / 255, alpha: 1.0)
        case .rootage: return UIColor(red: 234 / 255, green: 172 / 255, blue: 9 / 255, alpha: 1.0)
        case .heroicVerse: return UIColor(red: 224 / 255, green: 128 / 255, blue: 236 / 255, alpha: 1.0)
        case .bistrover: return UIColor(red: 112 / 255, green: 214 / 255, blue: 233 / 255, alpha: 1.0)
        case .castHour: return UIColor(red: 254 / 255, green: 165 / 255, blue: 89 / 255, alpha: 1.0)
        case .resident: return UIColor(red: 127 / 255, green: 158 / 255, blue: 166 / 255, alpha: 1.0)
        case .epolis: return UIColor(red: 240 / 255, green: 254 / 255, blue: 0 / 255, alpha: 1.0)
        case .pinkyCrush: return UIColor(red: 255 / 255, green: 97 / 255, blue: 178 / 255, alpha: 1.0)
        }
    }

    // swiftlint:disable line_length
    func loginPageRedirectURL() -> URL {
        return URL(string: """
https://p.eagate.573.jp/gate/p/login.html?path=http%3A%2F%2Fp.eagate.573.jp%2Fgame%2F2dx%2F\(self.rawValue)%2Fdjdata%2Fscore_download.html
""")!
    }

    func loginPageURL() -> URL {
        return URL(string: """
https://my1.konami.net/ja/signin
""")!
    }

    func downloadPageURL() -> URL {
        return URL(string: """
https://p.eagate.573.jp/game/2dx/\(self.rawValue)/djdata/score_download.html
""")!
    }

    func errorPageURL() -> URL {
        return URL(string: """
https://p.eagate.573.jp/game/2dx/\(self.rawValue)/error/error.html
""")!
    }

    func towerURL() -> URL {
        return URL(string: """
https://p.eagate.573.jp/game/2dx/\(self.rawValue)/djdata/tower.html
""")!
    }
    // swiftlint:enable line_length
}
