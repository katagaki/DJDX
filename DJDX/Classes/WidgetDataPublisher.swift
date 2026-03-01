//
//  WidgetDataPublisher.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import Foundation
import WidgetKit

actor WidgetDataPublisher {
    static let shared = WidgetDataPublisher()
    private let store = WidgetDataStore.shared
    private let fetcher = DataFetcher()

    func publishAll(playType: IIDXPlayType, iidxVersion: IIDXVersion) async {
        await publishClearTypeAndDJLevel(playType: playType, iidxVersion: iidxVersion)
        await publishTower()
        publishRadar()
        publishQpro()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func publishClearTypeAndDJLevel(playType: IIDXPlayType, iidxVersion: IIDXVersion) async {
        guard let importGroupID = await fetcher.importGroupID(for: .now) else { return }
        let result = await fetcher.aggregatedCounts(for: [importGroupID], playType: playType)

        let clearTypeData = result.clearType[importGroupID] ?? [:]
        let djLevelData = result.djLevel[importGroupID] ?? [:]

        let importGroups = await fetcher.importGroups(for: iidxVersion)
        let importGroupIDs = importGroups.map(\.id)
        let idToDate = Dictionary(uniqueKeysWithValues: importGroups.map { ($0.id, $0.importDate) })

        let trendResult = await fetcher.aggregatedCounts(for: importGroupIDs, playType: playType)

        var clearTypeTrends: [String: [Int: [String: Int]]] = [:]
        var djLevelTrends: [String: [Int: [String: Int]]] = [:]

        for igID in importGroupIDs {
            guard let date = idToDate[igID] else { continue }
            let dateKey = String(date.timeIntervalSince1970)
            if let clearType = trendResult.clearType[igID] {
                clearTypeTrends[dateKey] = clearType
            }
            if let djLevel = trendResult.djLevel[igID] {
                djLevelTrends[dateKey] = djLevel
            }
        }

        store.writeClearType(WidgetClearTypeSnapshot(
            dataPerDifficulty: clearTypeData,
            trendData: clearTypeTrends,
            playType: playType.rawValue,
            lastUpdated: .now
        ))

        store.writeDJLevel(WidgetDJLevelSnapshot(
            dataPerDifficulty: djLevelData,
            trendData: djLevelTrends,
            playType: playType.rawValue,
            lastUpdated: .now
        ))

        WidgetCenter.shared.reloadTimelines(ofKind: "ClearTypeWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "DJLevelWidget")
    }

    func publishTower() async {
        let entries = await fetcher.allTowerEntries()
        let totalKeys = entries.reduce(0) { $0 + $1.keyCount } / 100
        let totalScratch = entries.reduce(0) { $0 + $1.scratchCount } / 100

        let latestEntries = Array(entries.prefix(3)).map { entry in
            WidgetTowerEntry(playDate: entry.playDate, keyCount: entry.keyCount, scratchCount: entry.scratchCount)
        }

        store.writeTower(WidgetTowerSnapshot(
            totalKeyCount: totalKeys,
            totalScratchCount: totalScratch,
            latestEntries: latestEntries,
            lastUpdated: .now
        ))

        WidgetCenter.shared.reloadTimelines(ofKind: "TowerWidget")
    }

    func publishRadar() {
        let defaults = UserDefaults.standard
        var spData: WidgetRadarData?
        var dpData: WidgetRadarData?

        if defaults.object(forKey: "NotesRadar.SP.Notes") != nil {
            spData = WidgetRadarData(
                notes: defaults.double(forKey: "NotesRadar.SP.Notes"),
                chord: defaults.double(forKey: "NotesRadar.SP.Chord"),
                peak: defaults.double(forKey: "NotesRadar.SP.Peak"),
                charge: defaults.double(forKey: "NotesRadar.SP.Charge"),
                scratch: defaults.double(forKey: "NotesRadar.SP.Scratch"),
                soflan: defaults.double(forKey: "NotesRadar.SP.Soflan")
            )
        }
        if defaults.object(forKey: "NotesRadar.DP.Notes") != nil {
            dpData = WidgetRadarData(
                notes: defaults.double(forKey: "NotesRadar.DP.Notes"),
                chord: defaults.double(forKey: "NotesRadar.DP.Chord"),
                peak: defaults.double(forKey: "NotesRadar.DP.Peak"),
                charge: defaults.double(forKey: "NotesRadar.DP.Charge"),
                scratch: defaults.double(forKey: "NotesRadar.DP.Scratch"),
                soflan: defaults.double(forKey: "NotesRadar.DP.Soflan")
            )
        }

        store.writeRadar(WidgetRadarSnapshot(spData: spData, dpData: dpData, lastUpdated: .now))
        WidgetCenter.shared.reloadTimelines(ofKind: "NotesRadarWidget")
    }

    func publishQpro() {
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return }

        let fileURL = documentsDirectory.appendingPathComponent("Qpro.png")
        if let imageData = try? Data(contentsOf: fileURL) {
            store.writeQproImage(imageData)
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "QproWidget")
    }
}
