//
//  MoreView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Komponents
import SwiftUI
import WebKit

struct MoreView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.dismiss) var dismiss

    let importer = DataImporter()

    @AppStorage(wrappedValue: false, "ScoresView.LevelsShownSeparately") var isLevelsShownSeparately: Bool
    @AppStorage(wrappedValue: false, "ScoresView.BeginnerLevelHidden") var isBeginnerLevelHidden: Bool

    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    @State var morePath = NavigationPath()

    @State var isConfirmingWebDataDelete: Bool = false
    @State var isConfirmingScoreDataDelete: Bool = false
    @State var isConfirmingOldDataDelete: Bool = false

    var body: some View {
        NavigationStack(path: $morePath) {
            List {
                Section {
                    Picker(selection: $iidxVersion) {
                        ForEach(IIDXVersion.supportedVersions.reversed(), id: \.self) { version in
                            Text(version.marketingName)
                        }
                    } label: {
                        Text("Shared.IIDX.Version")
                    }
                    NavigationLink("More.General.AppIcon", value: MorePath.moreAppIcon)
                    NavigationLink("More.ExternalData.Header", value: MorePath.moreExternalDataSources)
                        .popoverTip(ImportWikiDataTip())
                    Toggle("More.PlayDataDisplay.HideBeginnerLevel", isOn: $isBeginnerLevelHidden)
                } header: {
                    Text("More.General.Header")
                }
                Section {
                    Group {
                        Button("More.ManageData.DeleteWebData") {
                            isConfirmingWebDataDelete = true
                        }
                        Button("More.ManageData.DeleteScoreData") {
                            isConfirmingScoreDataDelete = true
                        }
                        if UserDefaults.standard.bool(forKey: "Internal.DataMigrationForSwiftDataToSQLite") &&
                            !UserDefaults.standard.bool(forKey: "Internal.DataMigrationDeleteOldSQLiteData") {
                            Button("More.ManageData.DeleteOldData") {
                                isConfirmingOldDataDelete = true
                            }
                        }
                    }
                    .tint(.red)
                } header: {
                    Text("More.ManageData.Header")
                }
                Section {
                    Link(destination: URL(string: "https://github.com/katagaki/DJDX")!) {
                        HStack {
                            Text(String(localized: "More.GitHub"))
                            Spacer()
                            Text("katagaki/DJDX")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                    NavigationLink("More.Attributions", value: MorePath.moreAttributions)
                }
            }
            .navigator("ViewTitle.More", group: true)
            .scrollContentBackground(.hidden)
            .listSectionSpacing(.compact)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Shared.Done", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .alert(
                "Alert.DeleteData.Web.Title",
                isPresented: $isConfirmingWebDataDelete,
                actions: {
                    Button("Alert.DeleteData.Web.Confirm", role: .destructive) {
                        deleteAllWebData()
                    }
                    Button("Shared.Cancel", role: .cancel) {
                        isConfirmingWebDataDelete = false
                    }
                },
                message: {
                    Text("Alert.DeleteData.Web.Subtitle")
                })
            .alert(
                "Alert.DeleteData.Score.Title",
                isPresented: $isConfirmingScoreDataDelete,
                actions: {
                    Button("Alert.DeleteData.Score.Confirm", role: .destructive) {
                        deleteAllScoreData()
                    }
                    Button("Shared.Cancel", role: .cancel) {
                        isConfirmingScoreDataDelete = false
                    }
                },
                message: {
                    Text("Alert.DeleteData.Score.Subtitle")
                })
            .alert(
                "Alert.DeleteData.OldData.Title",
                isPresented: $isConfirmingOldDataDelete,
                actions: {
                    Button("Alert.DeleteData.OldData.Confirm", role: .destructive) {
                        deleteOldSwiftDataData()
                    }
                    Button("Shared.Cancel", role: .cancel) {
                        isConfirmingOldDataDelete = false
                    }
                },
                message: {
                    Text("Alert.DeleteData.OldData.Subtitle")
                })
            .navigationDestination(for: MorePath.self, destination: { viewPath in
                switch viewPath {
                case .moreExternalDataSources: MoreExternalDataSources()
                case .moreAppIcon: MoreAppIconView()
                case .moreAttributions: MoreLicensesView()
                }
            })
        }
    }

    func deleteAllWebData() {
        WKWebsiteDataStore.default()
            .fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                records.forEach { record in
                    WKWebsiteDataStore.default().removeData(
                        ofTypes: record.dataTypes,
                        for: [record],
                        completionHandler: {}
                    )
                }
            }
    }

    func deleteAllScoreData() {
        Task {
            await importer.deleteAllScoreData()
        }
    }

    func deleteOldSwiftDataData() {
        try? modelContext.delete(model: IIDXSongRecord.self)
        try? modelContext.delete(model: ImportGroup.self)
        try? modelContext.delete(model: IIDXSong.self)
        try? modelContext.delete(model: IIDXTowerEntry.self)
        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: "Internal.DataMigrationDeleteOldSQLiteData")
    }
}
