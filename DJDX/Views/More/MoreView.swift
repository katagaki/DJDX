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
    @EnvironmentObject var navigationManager: NavigationManager

    let importer = DataImporter()

    @AppStorage(wrappedValue: false, "ScoresView.LevelsShownSeparately") var isLevelsShownSeparately: Bool
    @AppStorage(wrappedValue: false, "ScoresView.BeginnerLevelHidden") var isBeginnerLevelHidden: Bool

    @AppStorage(wrappedValue: false, "ScoresView.GenreVisible") var isGenreVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ArtistVisible") var isArtistVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.LevelVisible") var isLevelVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.DJLevelVisible") var isDJLevelVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ScoreRateVisible") var isScoreRateVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ScoreVisible") var isScoreVisible: Bool
    @AppStorage(wrappedValue: false, "ScoresView.LastPlayDateVisible") var isLastPlayDateVisible: Bool

    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    @State var qproImage: UIImage?
    @State var spRadarData: RadarData?
    @State var dpRadarData: RadarData?

    @State var isConfirmingWebDataDelete: Bool = false
    @State var isConfirmingScoreDataDelete: Bool = false
    @State var isConfirmingOldDataDelete: Bool = false

    var body: some View {
        NavigationStack(path: $navigationManager[.more]) {
            List {
                if let qproImage {
                    Section {
                        Image(uiImage: qproImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 240.0, alignment: .center)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        if spRadarData != nil || dpRadarData != nil {
                            MoreNotesRadarView(spRadarData: spRadarData, dpRadarData: dpRadarData)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets())
                        }
                    }
                }
                Section {
                    NavigationLink(value: ViewPath.moreExternalDataSources) {
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text("More.ExternalData.Header")
                            Text("More.ExternalData.Description")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .popoverTip(ImportWikiDataTip())
                } header: {
                    ListSectionHeader(text: "More.ExternalData.Header")
                        .font(.body)
                }
                Section {
                    Picker(selection: $iidxVersion) {
                        ForEach(IIDXVersion.supportedVersions.reversed(), id: \.self) { version in
                            Text(version.marketingName)
                        }
                    } label: {
                        Text("Shared.IIDX.Version")
                    }
                    NavigationLink("More.General.AppIcon", value: ViewPath.moreAppIcon)
                    Toggle("More.PlayDataDisplay.HideBeginnerLevel", isOn: $isBeginnerLevelHidden)
                } header: {
                    ListSectionHeader(text: "More.General.Header")
                        .font(.body)
                }
                Section {
                    Toggle("More.PlayDataDisplay.ShowGenre", isOn: $isGenreVisible)
                    Toggle("More.PlayDataDisplay.ShowArtist", isOn: $isArtistVisible)
                    Toggle("More.PlayDataDisplay.ShowLevel", isOn: $isLevelVisible)
                    Toggle("Shared.IIDX.DJLevel", isOn: $isDJLevelVisible)
                    Toggle("Shared.Sort.ScoreRate", isOn: $isScoreRateVisible)
                    Toggle("Shared.Sort.Score", isOn: $isScoreVisible)
                    Toggle("Shared.Sort.LastPlayDate", isOn: $isLastPlayDateVisible)
                } header: {
                    ListSectionHeader(text: "More.PlayDataDisplay.Header")
                        .font(.body)
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
                    ListSectionHeader(text: "More.ManageData.Header")
                        .font(.body)
                }
                Section {
                    Link(destination: URL(string: "https://github.com/katagaki/DJDX")!) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2.0) {
                                Text("More.GitHub")
                                Text(verbatim: "katagaki/DJDX")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            Spacer()
                            Image(systemName: "safari")
                                .opacity(0.5)
                        }
                        .tint(.primary)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    NavigationLink("More.Attributions", value: ViewPath.moreAttributions)
                }
            }
            .navigator("ViewTitle.More", group: true)
            .scrollContentBackground(.hidden)
            .task {
                loadRadarData()
                if qproImage == nil {
                    await refreshStatusPageData()
                }
            }
            .refreshable {
                await refreshStatusPageData()
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
            .navigationDestination(for: ViewPath.self, destination: { viewPath in
                switch viewPath {
                case .moreExternalDataSources: MoreExternalDataSources()
                case .moreAppIcon: MoreAppIconView()
                case .moreAttributions: MoreLicensesView()
                default: Color.clear
                }
            })
        }
    }

    func refreshStatusPageData() async {
        qproImage = loadQproImage()
        if qproImage == nil {
            await downloadStatusPageData()
            withAnimation {
                qproImage = loadQproImage()
            }
        } else {
            await downloadStatusPageData()
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
