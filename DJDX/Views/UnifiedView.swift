import StoreKit
import SwiftUI
import TipKit

struct UnifiedView: View {

    @Environment(\.requestReview) var requestReview

    @EnvironmentObject var navigationManager: NavigationManager

    @AppStorage(wrappedValue: Game.iidxArcade, "Global.SelectedGame") var selectedGame: Game
    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion
    @AppStorage(wrappedValue: SDVXVersion.nabla, "Global.SDVX.Version") var sdvxVersion: SDVXVersion
    @AppStorage(wrappedValue: PolarisChordVersion.polarisChord, "Global.PolarisChord.Version")
    var polarisChordVersion: PolarisChordVersion
    @AppStorage(wrappedValue: DDRVersion.world, "Global.DDR.Version") var ddrVersion: DDRVersion
    @AppStorage(wrappedValue: DDRPlayStyle.single, "Global.DDR.Style") var ddrStyleToShow: DDRPlayStyle
    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var playTypeToShow: IIDXPlayType
    @AppStorage(wrappedValue: true, "More.General.ShowProfileHeader") var showProfileHeader: Bool
    @AppStorage(wrappedValue: true, "More.General.ShowAnalytics") var showAnalytics: Bool
    @AppStorage(wrappedValue: AppMode.imports, "Global.AppMode") var appMode: AppMode

    @AppStorage(wrappedValue: false, "Review.IsPrompted", store: .standard) var hasReviewBeenPrompted: Bool
    @AppStorage(wrappedValue: 0, "Review.LaunchCount", store: .standard) var launchCount: Int
    @AppStorage(wrappedValue: false, ICloudBackupManager.restorePromptCompletedKey)
    var hasCompletedRestorePrompt: Bool

    @State var isPresentingImport: Bool = false
    @State var isFirstStartCleanupComplete: Bool = false
    @State var isEditingAnalytics: Bool = false

    @State var availableBackupDate: Date?
    @State var isPromptingBackupRestore: Bool = false
    @State var isBackupRestoreCompleted: Bool = false
    @State var isBackupRestoreFailed: Bool = false

    @State var migrationProgress = ProgressReporter()

    @State var analyticsModel = AnalyticsModel()
    @State var sdvxAnalyticsModel = SDVXAnalyticsModel()
    @State var polarisChordAnalyticsModel = PolarisChordAnalyticsModel()
    @State var ddrAnalyticsModel = DDRAnalyticsModel()
    @State var sessionStore = SessionStore()

    @Namespace var analyticsNamespace
    @Namespace var sdvxAnalyticsNamespace
    @Namespace var polarisChordAnalyticsNamespace
    @Namespace var ddrAnalyticsNamespace
    @Namespace var towerNamespace
    @Namespace var importNamespace

    var body: some View {
        @Bindable var migrationProgress = migrationProgress
        NavigationStack(path: $navigationManager.path) {
            ZStack {
                if appMode == .sessions {
                    SessionsView(store: sessionStore)
                } else if selectedGame == .soundVoltex {
                    SDVXScoresView(isEditingAnalytics: $isEditingAnalytics) {
                        sdvxHeader
                    }
                } else if selectedGame == .polarisChord {
                    PolarisChordScoresView(isEditingAnalytics: $isEditingAnalytics) {
                        polarisChordHeader
                    }
                } else if selectedGame == .danceDanceRevolution {
                    DDRScoresView(isEditingAnalytics: $isEditingAnalytics) {
                        ddrHeader
                    }
                } else {
                    IIDXScoresView(isEditingAnalytics: $isEditingAnalytics) {
                        iidxHeader
                    }
                }
            }
            .navigationTitle(appMode == .sessions ? "ViewTitle.Sessions" : "ViewTitle.Scores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .principal) {
                    gameMenu
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Picker("ViewTitle.Mode", selection: $appMode) {
                        Label("ViewTitle.Scores", systemImage: "music.note.list").tag(AppMode.imports)
                        Label("ViewTitle.Sessions", systemImage: "figure.dance").tag(AppMode.sessions)
                    }
                    .pickerStyle(.menu)
                }
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .topBarLeading)
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    if appMode == .sessions {
                        Button {
                            if sessionStore.activeSession == nil {
                                sessionStore.startSession()
                            } else {
                                sessionStore.endSession()
                            }
                        } label: {
                            if sessionStore.activeSession == nil {
                                Label("Sessions.Start", systemImage: "play.circle.fill")
                            } else {
                                Label("Sessions.End", systemImage: "stop.circle.fill")
                            }
                        }
                    } else {
                        Button("Shared.Import", systemImage: "arrow.down.circle.dotted") {
                            isPresentingImport = true
                        }
                        .popoverTip(ImportMovedTip(), arrowEdge: .top)
                        .automaticSheetMatchedTransitionSource(id: "Import", in: importNamespace)
                    }
                }
                if appMode == .imports {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.smooth.speed(2.0)) { isEditingAnalytics.toggle() }
                        } label: {
                            if isEditingAnalytics {
                                Label("Shared.Done", systemImage: "checkmark")
                            } else {
                                Label("Shared.Edit", systemImage: "pencil")
                            }
                        }
                    }
                }
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    MoreMenu()
                }
            }
            .navigationDestination(for: MorePath.self) { viewPath in
                switch viewPath {
                case .moreExternalDataSources: MoreExternalDataSources()
                case .moreAttributions: MoreLicensesView()
                }
            }
            .navigationDestination(for: AnalyticsPath.self) { viewPath in
                AnalyticsDestinationView(
                    model: analyticsModel,
                    path: viewPath,
                    analyticsNamespace: analyticsNamespace
                )
            }
            .navigationDestination(for: TowerPath.self) { path in
                TowerDetailContainer(path: path)
                    .automaticNavigationTransition(
                        id: path == .recent ? "Tower.Recent" : "Tower.Totals",
                        in: towerNamespace
                    )
            }
            .navigationDestination(for: SDVXAnalyticsPath.self) { path in
                SDVXAnalyticsDestinationView(
                    model: sdvxAnalyticsModel,
                    path: path,
                    namespace: sdvxAnalyticsNamespace
                )
            }
            .navigationDestination(for: PolarisChordAnalyticsPath.self) { path in
                PolarisChordAnalyticsDestinationView(
                    model: polarisChordAnalyticsModel,
                    path: path,
                    namespace: polarisChordAnalyticsNamespace
                )
            }
            .navigationDestination(for: DDRAnalyticsPath.self) { path in
                DDRAnalyticsDestinationView(model: ddrAnalyticsModel, path: path, namespace: ddrAnalyticsNamespace)
            }
        }
        .sheet(isPresented: $isPresentingImport) {
            Group {
                if selectedGame == .soundVoltex {
                    SDVXImportView()
                } else if selectedGame == .polarisChord {
                    PolarisChordImportView()
                } else if selectedGame == .danceDanceRevolution {
                    DDRImportView()
                } else {
                    IIDXImportView()
                }
            }
            .automaticSheetNavigationTransition(id: "Import", in: importNamespace)
            .presentationDetents([.large])
            .interactiveDismissDisabled()
        }
        .fullScreenCover(isPresented: $migrationProgress.isShowing) {
            ProgressCard(
                title: migrationProgress.title,
                message: migrationProgress.message,
                percentage: migrationProgress.percentage
            )
            .presentationBackground(.clear)
        }
        .onOpenURL { url in
#if DEBUG
            if url.scheme == "djdx", url.host == "max300" {
                Task { await runFakeMigration() }
                return
            }
#endif
            handleDeepLink(url)
        }
        .task {
            if !isFirstStartCleanupComplete {
                await migrateData()
                isFirstStartCleanupComplete = true
            }
            try? Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ])
            launchCount += 1
            if launchCount > 2 && !hasReviewBeenPrompted {
                requestReview()
                hasReviewBeenPrompted = true
            }
            if !hasCompletedRestorePrompt {
                if await hasExistingPlayData() {
                    hasCompletedRestorePrompt = true
                } else {
                    let backupDate = await ICloudBackupManager.existingBackupDate()
                    // Re-check: the user may have made their own backup while the check was in flight.
                    if let backupDate, !hasCompletedRestorePrompt {
                        availableBackupDate = backupDate
                        isPromptingBackupRestore = true
                    }
                }
            }
        }
        .alert("Alert.ICloudBackup.Restore.Title", isPresented: $isPromptingBackupRestore) {
            Button("Alert.ICloudBackup.Restore.Confirm") {
                restoreFromBackup()
            }
            Button("Alert.ICloudBackup.Restore.Decline", role: .cancel) {
                hasCompletedRestorePrompt = true
            }
        } message: {
            Text("Alert.ICloudBackup.Restore.Subtitle.\(availableBackupDate ?? .now, format: .dateTime)")
        }
        .alert("Alert.ICloudBackup.RestoreCompleted.Title", isPresented: $isBackupRestoreCompleted) {
            Button("Shared.OK", role: .cancel) {
                isBackupRestoreCompleted = false
            }
        } message: {
            Text("Alert.ICloudBackup.RestoreCompleted.Subtitle")
        }
        .alert("Alert.ICloudBackup.RestoreFailed.Title", isPresented: $isBackupRestoreFailed) {
            Button("Shared.OK", role: .cancel) {
                isBackupRestoreFailed = false
            }
        } message: {
            Text("Alert.ICloudBackup.RestoreFailed.Subtitle")
        }
    }

}
