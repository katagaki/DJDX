//
//  SettingsMenu.swift
//  DJDX
//
//  Created by Claude on 2026/05/29.
//

import SwiftUI
import WebKit

struct SettingsMenu: View {

    @EnvironmentObject var navigationManager: NavigationManager

    let importer = DataImporter()

    @AppStorage(wrappedValue: false, "ScoresView.BeginnerLevelHidden") var isBeginnerLevelHidden: Bool

    @State var isPresentingExternalDataSources: Bool = false
    @State var isConfirmingWebDataDelete: Bool = false
    @State var isConfirmingResetLayout: Bool = false
    @State var isPromptingScoreDeleteCode: Bool = false
    @State var isConfirmingScoreDataDelete: Bool = false
    @State var scoreDeleteCode: String = ""
    @State var scoreDeleteCodeEntry: String = ""

    let appIcons: [AppIconChoice] = [
        AppIconChoice("Sparkle Shower", imageName: nil),
        AppIconChoice("Pinky Crush", imageName: "AppIcon.32"),
        AppIconChoice("EPOLIS", imageName: "AppIcon.31"),
        AppIconChoice("RESIDENT", imageName: "AppIcon.30"),
        AppIconChoice("CastHour", imageName: "AppIcon.29"),
        AppIconChoice("BISTROVER", imageName: "AppIcon.28"),
        AppIconChoice("HEROIC VERSE", imageName: "AppIcon.27")
    ]

    var body: some View {
        Menu {
            Section("More.General.Header") {
                Menu {
                    ForEach(appIcons, id: \.name) { icon in
                        Button {
                            UIApplication.shared.setAlternateIconName(icon.imageName) { error in
                                if let error {
                                    debugPrint(error.localizedDescription)
                                }
                            }
                        } label: {
                            Label {
                                Text(verbatim: icon.name)
                            } icon: {
                                Image(icon.previewImageName)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(.rect(cornerRadius: 8.0))
                            }
                        }
                    }
                } label: {
                    Text("More.General.AppIcon")
                }
                Button {
                    isPresentingExternalDataSources = true
                } label: {
                    Label {
                        Text("More.ExternalData.Header")
                    } icon: {
                        Image(.iconAnalytics)
                    }
                }
                Toggle("More.PlayDataDisplay.HideBeginnerLevel", isOn: $isBeginnerLevelHidden)
            }
            Section("More.ManageData.Header") {
                Button("More.ManageData.DeleteWebData", systemImage: "trash", role: .destructive) {
                    isConfirmingWebDataDelete = true
                }
                Button("More.ManageData.DeleteScoreData", systemImage: "trash", role: .destructive) {
                    beginScoreDataDelete()
                }
                Button("More.ManageData.ResetLayout", systemImage: "arrow.counterclockwise") {
                    isConfirmingResetLayout = true
                }
            }
            Section {
                Link(destination: URL(string: "https://github.com/katagaki/DJDX")!) {
                    Label("More.GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Button("More.Attributions") {
                    navigationManager.push(MorePath.moreAttributions)
                }
            }
        } label: {
            Label("Tab.More", systemImage: "ellipsis")
        }
        .sheet(isPresented: $isPresentingExternalDataSources) {
            NavigationStack {
                MoreExternalDataSources()
            }
        }
        .alert("Alert.DeleteData.Web.Title", isPresented: $isConfirmingWebDataDelete) {
            Button("Alert.DeleteData.Web.Confirm", role: .destructive) {
                deleteAllWebData()
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: {
            Text("Alert.DeleteData.Web.Subtitle")
        }
        .alert("Alert.ResetLayout.Title", isPresented: $isConfirmingResetLayout) {
            Button("Alert.ResetLayout.Confirm", role: .destructive) {
                resetLayout()
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: {
            Text("Alert.ResetLayout.Subtitle")
        }
        .alert("Alert.DeleteData.Score.Code.Title", isPresented: $isPromptingScoreDeleteCode) {
            TextField("Alert.DeleteData.Score.Code.Placeholder", text: $scoreDeleteCodeEntry)
                .keyboardType(.numberPad)
            Button("Shared.Continue") {
                if scoreDeleteCodeEntry == scoreDeleteCode {
                    isConfirmingScoreDataDelete = true
                }
            }
            Button("Shared.Cancel", role: .cancel) {
                scoreDeleteCodeEntry = ""
            }
        } message: {
            Text("Alert.DeleteData.Score.Code.Subtitle\(scoreDeleteCode)")
        }
        .alert("Alert.DeleteData.Score.Title", isPresented: $isConfirmingScoreDataDelete) {
            Button("Alert.DeleteData.Score.Confirm", role: .destructive) {
                deleteAllScoreData()
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: {
            Text("Alert.DeleteData.Score.Subtitle")
        }
    }

    func beginScoreDataDelete() {
        scoreDeleteCode = String(format: "%06d", Int.random(in: 0...999999))
        scoreDeleteCodeEntry = ""
        isPromptingScoreDeleteCode = true
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

    func resetLayout() {
        let defaults = UserDefaults.standard
        let encoder = JSONEncoder()
        defaults.set((try? encoder.encode(AnalyticsCardType.defaultOrder)) ?? Data(),
                     forKey: "Analytics.CardOrder")
        defaults.set((try? encoder.encode(AnalyticsCardType.defaultVisible)) ?? Data(),
                     forKey: "Analytics.VisibleCards")
        defaults.set((try? encoder.encode(PerLevelCardID.defaultOrder)) ?? Data(),
                     forKey: "Analytics.PerLevelCardOrder")
        defaults.set((try? encoder.encode(PerLevelCardID.defaultVisible)) ?? Data(),
                     forKey: "Analytics.VisiblePerLevelCards")
        NotificationCenter.default.post(name: .analyticsLayoutReset, object: nil)
    }
}

struct AppIconChoice {
    let name: String
    let imageName: String?

    init(_ name: String, imageName: String?) {
        self.name = name
        self.imageName = imageName
    }

    var previewImageName: String {
        if let imageName {
            "\(imageName).Preview"
        } else {
            "AppIcon.Preview"
        }
    }
}
