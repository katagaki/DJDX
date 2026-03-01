//
//  WidgetDataModels.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import Foundation

// MARK: - Shared Container Access

enum SharedContainer {
    static let appGroupID = "group.com.tsubuzaki.DJDX"

    static var containerURL: URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        )!
    }

    static var widgetDataURL: URL {
        containerURL.appendingPathComponent("WidgetData")
    }
}

// MARK: - Widget Snapshot Models

struct WidgetRadarData: Codable, Sendable {
    let notes: Double
    let chord: Double
    let peak: Double
    let charge: Double
    let scratch: Double
    let soflan: Double

    var sum: Double {
        [notes, chord, peak, charge, scratch, soflan].reduce(0, +)
    }
}

struct WidgetRadarSnapshot: Codable, Sendable {
    let spData: WidgetRadarData?
    let dpData: WidgetRadarData?
    let lastUpdated: Date
}

struct WidgetClearTypeSnapshot: Codable, Sendable {
    let dataPerDifficulty: [Int: [String: Int]]
    let trendData: [String: [Int: [String: Int]]]
    let playType: String
    let lastUpdated: Date
}

struct WidgetDJLevelSnapshot: Codable, Sendable {
    let dataPerDifficulty: [Int: [String: Int]]
    let trendData: [String: [Int: [String: Int]]]
    let playType: String
    let lastUpdated: Date
}

struct WidgetTowerSnapshot: Codable, Sendable {
    let totalKeyCount: Int
    let totalScratchCount: Int
    let latestEntries: [WidgetTowerEntry]
    let lastUpdated: Date
}

struct WidgetTowerEntry: Codable, Sendable {
    let playDate: Date
    let keyCount: Int
    let scratchCount: Int
}
