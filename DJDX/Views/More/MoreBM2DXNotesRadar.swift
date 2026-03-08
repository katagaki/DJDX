//
//  MoreBM2DXNotesRadar.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/03/08.
//

import Komponents
import SafariServices
import SwiftUI

struct MoreBM2DXNotesRadar: View {

    @Environment(ProgressAlertManager.self) var progressAlertManager
    @Environment(\.openURL) var openURL

    @State var entryCount: Int = 0

    @State var isReloadCompleted: Bool = false

    let fetcher = DataFetcher()
    let importer = DataImporter()

    var body: some View {
        List {
            Section {
                Button("More.ExternalData.UpdateData") {
                    progressAlertManager.show(title: "Alert.ExternalData.Downloading.Title",
                                              message: "Alert.ExternalData.Downloading.Text")
                    Task {
                        await reloadData()
                        isReloadCompleted = true
                    }
                }
            } footer: {
                Text("More.ExternalData.Disclaimer")
                    .font(.caption2)
            }
            Section {
                HStack {
                    Text("More.ExternalData.BM2DX.EntryCount")
                    Spacer()
                    Text(verbatim: "\(entryCount)")
                        .foregroundStyle(.secondary)
                }
            } header: {
                ListSectionHeader(text: "More.ExternalData.BM2DX.Data")
                    .font(.body)
            }
        }
        .navigationTitle("ViewTitle.More.BM2DXNotesRadar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    openURL(URL(string: "https://bm2dx.com/IIDX/notes_radar/")!)
                } label: {
                    Image(systemName: "safari")
                }
            }
        }
        .task {
            entryCount = await fetcher.chartRadarDataCount()
        }
        .alert(
            "Alert.ExternalData.Completed.Title",
            isPresented: $isReloadCompleted,
            actions: {
                Button("Shared.OK", role: .cancel) {
                    isReloadCompleted = false
                }
            },
            message: {
                Text("Alert.ExternalData.Completed.Text.\(entryCount)")
            }
        )
    }

    func reloadData() async {
        await importer.deleteAllNotesRadar()
        var allEntries: [ChartRadarData] = []

        do {
            let url = URL(string: "https://bm2dx.com/IIDX/notes_radar/notes_radar.json.gz")!
            let (data, _) = try await URLSession.shared.data(from: url)

            // Decompress gzip data
            guard let decompressedData = data.gunzip() else {
                await MainActor.run { progressAlertManager.hide() }
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: decompressedData) as? [String: Any],
                  let midDict = json["mid"] as? [String: String],
                  let notesRadar = json["notes_radar"] as? [String: [String: [[String: Any]]]] else {
                await MainActor.run { progressAlertManager.hide() }
                return
            }

            // Build a lookup: (playType, mid, difficulty) -> (noteCount, radar values per type)
            var lookup: [String: [String: [Int: (noteCount: Int, values: [String: Double])]]] = [:]

            for (playType, radarTypes) in notesRadar {
                for (radarType, entries) in radarTypes {
                    for entry in entries {
                        guard let mid = entry["mid"] as? String,
                              let difficulty = entry["difficult"] as? Int,
                              let noteCount = entry["note"] as? Int,
                              let value = entry["value"] as? Double else { continue }

                        lookup[playType, default: [:]][mid, default: [:]][difficulty, default: (
                            noteCount: noteCount,
                            values: [:]
                        )].noteCount = noteCount
                        lookup[playType, default: [:]][mid, default: [:]][difficulty, default: (
                            noteCount: noteCount,
                            values: [:]
                        )].values[radarType] = value
                    }
                }
            }

            // Convert lookup to ChartRadarData entries
            for (playType, mids) in lookup {
                for (mid, difficulties) in mids {
                    guard let title = midDict[mid] else { continue }
                    for (difficulty, data) in difficulties {
                        let radarData = RadarData(
                            notes: data.values["NOTES"] ?? 0.0,
                            chord: data.values["CHORD"] ?? 0.0,
                            peak: data.values["PEAK"] ?? 0.0,
                            charge: data.values["CHARGE"] ?? 0.0,
                            scratch: data.values["SCRATCH"] ?? 0.0,
                            soflan: data.values["SOFLAN"] ?? 0.0
                        )
                        allEntries.append(ChartRadarData(
                            title: title,
                            playType: playType,
                            difficulty: difficulty,
                            noteCount: data.noteCount,
                            radarData: radarData
                        ))
                    }
                }
            }
        } catch {
            debugPrint("Failed to fetch BM2DX data: \(error)")
        }

        await importer.insertNotesRadarEntries(allEntries)
        entryCount = await fetcher.chartRadarDataCount()

        await MainActor.run {
            progressAlertManager.hide()
        }
    }
}
