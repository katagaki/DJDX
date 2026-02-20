//
//  TowerView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/06.
//

import Charts
import SwiftData
import SwiftUI

struct TowerView: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @Query(sort: \IIDXTowerEntry.playDate, order: .reverse) var towerEntries: [IIDXTowerEntry]

    @State var isAutoImportFailed: Bool = false
    @State var didImportSucceed: Bool = false
    @State var autoImportFailedReason: ImportFailedReason?

    var chartEntries: [IIDXTowerEntry] {
        Array(towerEntries.prefix(5)).reversed()
    }

    var body: some View {
        NavigationStack(path: $navigationManager[.tower]) {
            Group {
                if towerEntries.isEmpty {
                    ContentUnavailableView(
                        "Tower.NoData.Title",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Tower.NoData.Description")
                    )
                } else {
                    List {
                        Section {
                            TowerBarChart(entries: chartEntries)
                                .frame(height: 240)
                                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                                .listRowBackground(Color.clear)
                        }
                        Section {
                            ForEach(towerEntries, id: \.playDate) { entry in
                                HStack {
                                    Text(entry.playDate, format: .dateTime.year().month().day())
                                        .monospacedDigit()
                                    Spacer()
                                    Group {
                                        Text("Count.\(entry.keyCount)")
                                            .monospacedDigit()
                                            .foregroundStyle(.blue)
                                            .frame(width: 80, alignment: .trailing)
                                        Text("Count.\(entry.scratchCount)")
                                            .monospacedDigit()
                                            .foregroundStyle(.red)
                                            .frame(width: 80, alignment: .trailing)
                                    }
                                }
                            }
                            .listRowBackground(Color.clear)
                        } header: {
                            HStack {
                                Text("Tower.Header.PlayDate")
                                Spacer()
                                Text("Tower.Header.Keys")
                                    .frame(width: 80, alignment: .trailing)
                                Text("Tower.Header.Scratch")
                                    .frame(width: 80, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .navigator("ViewTitle.Tower", inline: true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Shared.Import", systemImage: "square.and.arrow.down") {
                        navigationManager.push(ViewPath.importerWebIIDXTower, for: .tower)
                    }
                }
            }
            .alert(
                "Alert.Import.Success.Title",
                isPresented: $didImportSucceed,
                actions: {
                    Button("Shared.OK", role: .cancel) {
                        didImportSucceed = false
                    }
                },
                message: {
                    Text("Alert.Import.Success.Subtitle")
                }
            )
            .alert(
                "Alert.Import.Error.Title",
                isPresented: $isAutoImportFailed,
                actions: {
                    Button("Shared.OK", role: .cancel) {
                        isAutoImportFailed = false
                    }
                },
                message: {
                    Text(errorMessage(for: autoImportFailedReason ?? .serverError))
                }
            )
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .importerWebIIDXTower:
                    WebImporter(importMode: .tower,
                                isAutoImportFailed: $isAutoImportFailed,
                                didImportSucceed: $didImportSucceed,
                                autoImportFailedReason: $autoImportFailedReason)
                default: Color.clear
                }
            }
        }
    }

    func errorMessage(for reason: ImportFailedReason) -> String {
        switch reason {
        case .noPremiumCourse:
            return NSLocalizedString("Alert.Import.Error.Subtitle.NoPremiumCourse", comment: "")
        case .noEAmusementPass:
            return NSLocalizedString("Alert.Import.Error.Subtitle.NoEAmusementPass", comment: "")
        case .noPlayData:
            return NSLocalizedString("Alert.Import.Error.Subtitle.NoPlayData", comment: "")
        case .serverError:
            return NSLocalizedString("Alert.Import.Error.Subtitle.ServerError", comment: "")
        case .maintenance:
            return NSLocalizedString("Alert.Import.Error.Subtitle.Maintenance", comment: "")
        }
    }
}

struct TowerBarChart: View {
    let entries: [IIDXTowerEntry]

    var body: some View {
        Chart(entries, id: \.playDate) { entry in
            BarMark(
                x: .value("Tower.Header.PlayDate",
                          entry.playDate, unit: .day),
                y: .value("Tower.Header.Keys", entry.keyCount)
            )
            .foregroundStyle(.blue)
            .position(by: .value("Tower.Type", "Keys"))

            BarMark(
                x: .value("Tower.Header.PlayDate",
                          entry.playDate, unit: .day),
                y: .value("Tower.Header.Scratch", entry.scratchCount)
            )
            .foregroundStyle(.red)
            .position(by: .value("Tower.Type", "Scratch"))
        }
    }
}
