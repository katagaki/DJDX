//
//  IIDXClearType.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/02.
//

import Foundation

enum IIDXClearType: String, Codable {
    case all = "Shared.All"
    case fullComboClear = "FULLCOMBO CLEAR"
    case clear = "CLEAR"
    case assistClear = "ASSIST CLEAR"
    case easyClear = "EASY CLEAR"
    case hardClear = "HARD CLEAR"
    case exHardClear = "EX HARD CLEAR"
    case failed = "FAILED"
    case noPlay = "NO PLAY"
    case unknown = ""

    static let sorted: [IIDXClearType] = [
        .fullComboClear,
        .clear,
        .assistClear,
        .easyClear,
        .hardClear,
        .exHardClear,
        .failed,
        .noPlay
    ]

    static let sortedWithoutNoPlay: [IIDXClearType] = [
        .fullComboClear,
        .clear,
        .assistClear,
        .easyClear,
        .hardClear,
        .exHardClear,
        .failed
    ]

    static var sortedStrings: [String] {
        sorted.map({ $0.rawValue })
    }

    static var sortedStringsWithoutNoPlay: [String] {
        sortedWithoutNoPlay.map({ $0.rawValue })
    }
}
