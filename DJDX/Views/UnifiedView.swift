import StoreKit
import SwiftData
import SwiftUI
import TipKit

struct UnifiedView: View {

    @Environment(\.requestReview) var requestReview
    @Environment(\.modelContext) var modelContext

    @Environment(ProgressAlertManager.self) var progressAlertManager
    @EnvironmentObject var navigationManager: NavigationManager

    @AppStorage(wrappedValue: Game.iidxArcade, "Global.SelectedGame") var selectedGame: Game
    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion
    @AppStorage(wrappedValue: SDVXVersion.nabla, "Global.SDVX.Version") var sdvxVersion: SDVXVersion
    @AppStorage(wrappedValue: PolarisChordVersion.polarisChord, "Global.PolarisChord.Version")
    var polarisChordVersion: PolarisChordVersion
    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var playTypeToShow: IIDXPlayType
    @AppStorage(wrappedValue: true, "More.General.ShowProfileHeader") var showProfileHeader: Bool
    @AppStorage(wrappedValue: true, "More.General.ShowAnalytics") var showAnalytics: Bool

    @AppStorage(wrappedValue: false, "Review.IsPrompted", store: .standard) var hasReviewBeenPrompted: Bool
    @AppStorage(wrappedValue: 0, "Review.LaunchCount", store: .standard) var launchCount: Int

    @State var isPresentingImport: Bool = false
    @State var isFirstStartCleanupComplete: Bool = false
    @State var isEditingAnalytics: Bool = false

    @State var analyticsModel = AnalyticsModel()
    @State var sdvxAnalyticsModel = SDVXAnalyticsModel()

    @Namespace var analyticsNamespace
    @Namespace var sdvxAnalyticsNamespace
    @Namespace var towerNamespace
    @Namespace var importNamespace

    var body: some View {
        @Bindable var progressAlertManager = progressAlertManager
        NavigationStack(path: $navigationManager.path) {
            ZStack {
                if selectedGame == .soundVoltex {
                    SDVXScoresView(isEditingAnalytics: $isEditingAnalytics) {
                        sdvxHeader
                    }
                } else if selectedGame == .polarisChord {
                    PolarisChordScoresView(isEditingAnalytics: $isEditingAnalytics) {
                        polarisChordHeader
                    }
                } else {
                    IIDXScoresView(isEditingAnalytics: $isEditingAnalytics) {
                        iidxHeader
                    }
                }
            }
            .navigationTitle("ViewTitle.Scores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .principal) {
                    gameMenu
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Shared.Import", systemImage: "arrow.down.circle.dotted") {
                        isPresentingImport = true
                    }
                    .popoverTip(ImportMovedTip(), arrowEdge: .top)
                    .automaticSheetMatchedTransitionSource(id: "Import", in: importNamespace)
                }
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
        }
        .sheet(isPresented: $isPresentingImport) {
            Group {
                if selectedGame == .soundVoltex {
                    SDVXImportView()
                } else if selectedGame == .polarisChord {
                    PolarisChordImportView()
                } else {
                    IIDXImportView()
                }
            }
            .automaticSheetNavigationTransition(id: "Import", in: importNamespace)
            .presentationDetents([.large])
            .interactiveDismissDisabled()
        }
        .overlay {
            if progressAlertManager.isShowing {
                ProgressAlert(
                    title: $progressAlertManager.title,
                    message: $progressAlertManager.message
                )
            } else {
                // HACK: DO NOT REMOVE. Removing this will cause a freeze when isShowing is false.
                Color.clear
            }
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
        }
    }

    @ViewBuilder
    var iidxHeader: some View {
        VStack(spacing: 0.0) {
            if selectedGame.supportsPlayType {
                Picker("Shared.PlayType", selection: $playTypeToShow) {
                    Text(verbatim: "SP")
                        .tag(IIDXPlayType.single)
                    Text(verbatim: "DP")
                        .tag(IIDXPlayType.double)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8.0)
            }
            if selectedGame.supportsProfile && showProfileHeader {
                IIDXProfileHeaderView()
                    .padding(.horizontal)
                    .padding(.top, 16.0)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            if showAnalytics {
                AnalyticsView(model: analyticsModel,
                              isEditing: $isEditingAnalytics,
                              analyticsNamespace: analyticsNamespace,
                              towerNamespace: towerNamespace)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.bottom, 8.0)
        .animation(.smooth.speed(2.0), value: showProfileHeader)
        .animation(.smooth.speed(2.0), value: showAnalytics)
    }

    @ViewBuilder
    var sdvxHeader: some View {
        VStack(spacing: 0.0) {
            if showProfileHeader {
                SDVXProfileHeaderView()
                    .padding(.horizontal)
                    .padding(.top, 16.0)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            if showAnalytics {
                SDVXAnalyticsView(model: sdvxAnalyticsModel, isEditing: $isEditingAnalytics,
                                  analyticsNamespace: sdvxAnalyticsNamespace)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.bottom, 8.0)
        .animation(.smooth.speed(2.0), value: showProfileHeader)
        .animation(.smooth.speed(2.0), value: showAnalytics)
    }

    @ViewBuilder
    var polarisChordHeader: some View {
        VStack(spacing: 0.0) {
            if showProfileHeader {
                PolarisChordProfileHeaderView()
                    .padding(.horizontal)
                    .padding(.top, 16.0)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.bottom, 8.0)
        .animation(.snappy, value: showProfileHeader)
    }

    @ViewBuilder
    var gameMenu: some View {
        Menu {
            Section {
                Picker("Game", selection: $selectedGame) {
                    ForEach(Game.allCases.filter { $0.isAvailable }) { game in
                        if let iconResource = game.iconResource {
                            Label {
                                Text(game.displayName)
                            } icon: {
                                Image(iconResource)
                            }
                            .tag(game)
                        } else {
                            Text(game.displayName)
                                .tag(game)
                        }
                    }
                }
            }
            Section("Shared.Version") {
                if selectedGame == .soundVoltex {
                    Picker("Shared.Version", selection: $sdvxVersion) {
                        ForEach(SDVXVersion.supportedVersions.reversed(), id: \.self) { version in
                            Text(version.marketingName).tag(version)
                        }
                    }
                    .pickerStyle(.inline)
                } else if selectedGame == .polarisChord {
                    Picker("Shared.Version", selection: $polarisChordVersion) {
                        ForEach(PolarisChordVersion.supportedVersions, id: \.self) { version in
                            Text(version.marketingName).tag(version)
                        }
                    }
                    .pickerStyle(.inline)
                } else {
                    Picker("Shared.Version", selection: $iidxVersion) {
                        ForEach(IIDXVersion.supportedVersions.reversed(), id: \.self) { version in
                            Text(version.marketingName).tag(version)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .labelsVisibility(.visible)
        } label: {
            HStack(spacing: 4.0) {
                Text(selectedGame.displayName)
                    .fontWeight(.bold)
                    .tint(.primary)
                Image(systemName: "chevron.down.circle.fill")
                    .font(.caption2.bold())
                    .symbolRenderingMode(.hierarchical)
                    .tint(.secondary)
            }
        }
        .menuActionDismissBehavior(.disabled)
    }
}
