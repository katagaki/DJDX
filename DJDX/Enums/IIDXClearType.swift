//
//  IIDXClearType.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/02.
//

import Foundation
import SwiftUI

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

    /// Color for clear lamp display (used in ScoreRow)
    var lampColor: AnyShapeStyle {
        switch self {
        case .fullComboClear:
            return AnyShapeStyle(LinearGradient(
                gradient: Gradient(colors: [.red, .orange, .yellow, .green, .blue, .indigo, .purple]),
                startPoint: .top,
                endPoint: .bottom
            ))
        case .clear: return AnyShapeStyle(Color.cyan)
        case .assistClear: return AnyShapeStyle(Color.purple)
        case .easyClear: return AnyShapeStyle(Color.green)
        case .hardClear: return AnyShapeStyle(Color.pink)
        case .exHardClear: return AnyShapeStyle(Color.yellow)
        case .failed: return AnyShapeStyle(Color.red)
        default: return AnyShapeStyle(Color.clear)
        }
    }

    init(from rawValue: String) {
        self = IIDXClearType(rawValue: rawValue) ?? .unknown
    }
}
