//
//  TowerView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/06.
//

import SwiftUI

struct TowerView: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @State var towerEntries: [IIDXTowerEntry] = []

    @State var isAutoImportFailed: Bool = false
    @State var didImportSucceed: Bool = false
    @State var autoImportFailedReason: ImportFailedReason?

    let fetcher = DataFetcher()

    @AppStorage(wrappedValue: .totals, "TowerView.DisplayMode") var chartMode: TowerChartMode

    var chartEntries: [IIDXTowerEntry] {
        Array(towerEntries.prefix(5)).reversed()
    }

    var totalKeyCount: Int {
        towerEntries.reduce(0) { $0 + $1.keyCount } / 100
    }

    var totalScratchCount: Int {
        towerEntries.reduce(0) { $0 + $1.scratchCount } / 100
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
                            Picker("Tower.ChartMode", selection: $chartMode) {
                                Text("Tower.ChartMode.Recent")
                                    .tag(TowerChartMode.recent)
                                Text("Tower.ChartMode.Totals")
                                    .tag(TowerChartMode.totals)
                            }
                            .pickerStyle(.segmented)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        Section {
                            Group {
                                switch chartMode {
                                case .recent:
                                    TowerBarChart(entries: chartEntries)
                                case .totals:
                                    TowerTotalsChart(
                                        totalKeyCount: totalKeyCount,
                                        totalScratchCount: totalScratchCount
                                    )
                                }
                            }
                            .frame(height: 240)
                            .listRowSeparator(.hidden)
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
            .navigator("ViewTitle.Tower")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Shared.Import", systemImage: "arrow.clockwise") {
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
            .task {
                await reloadTowerEntries()
            }
            .onChange(of: didImportSucceed) { _, newValue in
                if newValue {
                    Task {
                        await reloadTowerEntries()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dataMigrationCompleted)) { _ in
                Task { await reloadTowerEntries() }
            }
        }
    }

    func reloadTowerEntries() async {
        towerEntries = await fetcher.allTowerEntries()
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
