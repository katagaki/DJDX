import SwiftUI
import WebKit

struct MoreMenu: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @AppStorage(wrappedValue: true, "More.General.ShowProfileHeader") var showProfileHeader: Bool
    @AppStorage(wrappedValue: true, "More.General.ShowAnalytics") var showAnalytics: Bool

    let importer = IIDXImporter()

    @State var isPresentingExternalDataSources: Bool = false
    @State var isConfirmingWebDataDelete: Bool = false
    @State var isConfirmingResetLayout: Bool = false
    @State var isPromptingScoreDeleteCode: Bool = false
    @State var isConfirmingScoreDataDelete: Bool = false
    @State var scoreDeleteCode: String = ""
    @State var scoreDeleteCodeEntry: String = ""

    let appIcons: [AppIconChoice] = [
        AppIconChoice("Default", imageName: nil, isNameLocalized: true),
        AppIconChoice("Sparkle Shower", imageName: "AppIcon.33"),
        AppIconChoice("Pinky Crush", imageName: "AppIcon.32"),
        AppIconChoice("EPOLIS", imageName: "AppIcon.31"),
        AppIconChoice("NABLA", imageName: "AppIcon.VII"),
        AppIconChoice("EXCEED GEAR", imageName: "AppIcon.VI")
    ]

    var body: some View {
        Menu {
            Section("More.General.Header") {
                Button("More.ExternalData.Header", image: .iconAnalytics) {
                    isPresentingExternalDataSources = true
                }
                Toggle("More.General.ShowProfileHeader", systemImage: "person.crop.circle", isOn: $showProfileHeader)
                Toggle("More.General.ShowAnalytics", systemImage: "chart.xyaxis.line", isOn: $showAnalytics)
            }
            Section {
                Menu("More.General.AppIcon", systemImage: "app.dashed") {
                    ForEach(appIcons, id: \.name) { icon in
                        Button {
                            UIApplication.shared.setAlternateIconName(icon.imageName) { error in
                                if let error {
                                    debugPrint(error.localizedDescription)
                                }
                            }
                        } label: {
                            Label {
                                if icon.isNameLocalized {
                                    Text(LocalizedStringKey(icon.name))
                                } else {
                                    Text(verbatim: icon.name)
                                }
                            } icon: {
                                Image(icon.previewImageName)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(.rect(cornerRadius: 8.0))
                            }
                        }
                    }
                }
            }
            Section("More.ManageData.Header") {
                Button("More.ManageData.ResetLayout", systemImage: "arrow.counterclockwise", role: .destructive) {
                    isConfirmingResetLayout = true
                }
                Button("More.ManageData.DeleteWebData", image: .globeSlash, role: .destructive) {
                    isConfirmingWebDataDelete = true
                }
                Button("More.ManageData.DeleteScoreData", systemImage: "trash", role: .destructive) {
                    beginScoreDataDelete()
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
        .menuActionDismissBehavior(.disabled)
        .sheet(isPresented: $isPresentingExternalDataSources) {
            NavigationStack {
                MoreExternalDataSources()
            }
        }
        .alert("Alert.DeleteData.Web.Title", isPresented: $isConfirmingWebDataDelete) {
            Button("Alert.DeleteData.Web.Confirm", role: .destructive) {
                deleteAllWebData()
            }
            Button("Shared.Cancel", role: .cancel) {
                // Dismisses the alert; no further action needed
            }
        } message: {
            Text("Alert.DeleteData.Web.Subtitle")
        }
        .alert("Alert.ResetLayout.Title", isPresented: $isConfirmingResetLayout) {
            Button("Alert.ResetLayout.Confirm", role: .destructive) {
                resetLayout()
            }
            Button("Shared.Cancel", role: .cancel) {
                // Dismisses the alert; no further action needed
            }
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
            Button("Shared.Cancel", role: .cancel) {
                // Dismisses the alert; no further action needed
            }
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
                        completionHandler: {
                            // Fire-and-forget removal; nothing to do on completion
                        }
                    )
                }
            }
    }

    func deleteAllScoreData() {
        Task {
            await importer.deleteAllScoreData()
            await MainActor.run {
                NotificationCenter.default.post(name: .dataImported, object: nil)
            }
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
    let isNameLocalized: Bool

    init(_ name: String, imageName: String?, isNameLocalized: Bool = false) {
        self.name = name
        self.imageName = imageName
        self.isNameLocalized = isNameLocalized
    }

    var previewImageName: String {
        if let imageName {
            "\(imageName).Preview"
        } else {
            "AppIcon.Preview"
        }
    }
}
