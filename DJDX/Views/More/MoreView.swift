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
                    NavigationLink(value: ViewPath.moreBemaniWikiCharts) {
                        ListRow(image: "ListIcon.BemaniWiki2nd",
                                title: "More.ExternalData.BemaniWiki2nd",
                                subtitle: "More.ExternalData.BemaniWiki2nd.Description")
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
                        ListRow(image: "ListIcon.Version",
                                title: "Shared.IIDX.Version")
                    }

                    NavigationLink(value: ViewPath.moreAppIcon) {
                        ListRow(image: "ListIcon.AppIcon",
                                title: "More.General.AppIcon")
                    }
                    // TODO: Implement this feature
                    // swiftlint:disable:next control_statement
                    if (false) {
                        Toggle(isOn: $isLevelsShownSeparately) {
                            HStack(spacing: 0.0) {
                                ListRow(image: "ListIcon.ShowLevelsAsSeparateRecords",
                                        title: "More.PlayDataDisplay.ShowLevelsSeparately",
                                        subtitle: "More.PlayDataDisplay.ShowLevelsSeparately.Description",
                                        includeSpacer: true)
                            }
                        }
                    }
                    Toggle(isOn: $isBeginnerLevelHidden) {
                        ListRow(image: "ListIcon.HideBeginner",
                                title: "More.PlayDataDisplay.HideBeginnerLevel",
                                includeSpacer: true)
                    }
                } header: {
                    ListSectionHeader(text: "More.General.Header")
                        .font(.body)
                }
                Section {
                    Toggle(isOn: $isGenreVisible) {
                        ListRow(image: "ListIcon.ShowGenre",
                                title: "More.PlayDataDisplay.ShowGenre",
                                includeSpacer: true)
                    }
                    Toggle(isOn: $isArtistVisible) {
                        ListRow(image: "ListIcon.ShowArtist",
                                title: "More.PlayDataDisplay.ShowArtist",
                                includeSpacer: true)
                    }
                    Toggle(isOn: $isLevelVisible) {
                        ListRow(image: "ListIcon.ShowLevel",
                                title: "More.PlayDataDisplay.ShowLevel",
                                includeSpacer: true)
                    }
                    Toggle(isOn: $isDJLevelVisible) {
                        ListRow(image: "ListIcon.ShowDJLevel",
                                title: "More.PlayDataDisplay.ShowDJLevel",
                                includeSpacer: true)
                    }
                    Toggle(isOn: $isScoreRateVisible) {
                        ListRow(image: "ListIcon.ShowScoreRate",
                                title: "More.PlayDataDisplay.ShowScoreRate",
                                includeSpacer: true)
                    }
                    Toggle(isOn: $isScoreVisible) {
                        ListRow(image: "ListIcon.ShowScore",
                                title: "More.PlayDataDisplay.ShowScore",
                                includeSpacer: true)
                    }
                    Toggle(isOn: $isLastPlayDateVisible) {
                        ListRow(image: "ListIcon.ShowPlayDate",
                                title: "More.PlayDataDisplay.ShowLastPlayDate",
                                includeSpacer: true)
                    }
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
                case .moreBemaniWikiCharts: MoreBemaniWikiCharts()
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
