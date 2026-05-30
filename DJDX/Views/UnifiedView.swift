//
//  UnifiedView.swift
//  DJDX
//
//  Created by Claude on 2026/05/29.
//

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
    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var playTypeToShow: IIDXPlayType

    @AppStorage(wrappedValue: false, "Review.IsPrompted", store: .standard) var hasReviewBeenPrompted: Bool
    @AppStorage(wrappedValue: 0, "Review.LaunchCount", store: .standard) var launchCount: Int

    @State var isPresentingImport: Bool = false
    @State var isFirstStartCleanupComplete: Bool = false
    @State var isEditingAnalytics: Bool = false

    @State var analyticsModel = AnalyticsModel()
    @State var sdvxAnalyticsModel = SDVXAnalyticsModel()

    @Namespace var importNamespace
    @Namespace var analyticsNamespace
    @Namespace var towerNamespace

    var body: some View {
        @Bindable var progressAlertManager = progressAlertManager
        NavigationStack(path: $navigationManager.path) {
            Group {
                if selectedGame == .soundVoltex {
                    SDVXScoresView(isEditingAnalytics: $isEditingAnalytics) {
                        sdvxHeader
                    }
                } else {
                    ScoresView(isEditingAnalytics: $isEditingAnalytics) {
                        unifiedHeader
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .principal) {
                    gameMenu
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Shared.Import", systemImage: "arrow.down.circle.dotted") {
                        isPresentingImport = true
                    }
                    .automaticMatchedTransitionSource(id: "ImportSheet", in: importNamespace)
                    .popoverTip(ImportMovedTip(), arrowEdge: .top)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.snappy) { isEditingAnalytics.toggle() }
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
                    SettingsMenu()
                }
            }
            .navigationDestination(for: MorePath.self) { viewPath in
                switch viewPath {
                case .moreExternalDataSources: MoreExternalDataSources()
                case .moreAppIcon: MoreAppIconView()
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
        }
        .sheet(isPresented: $isPresentingImport) {
            Group {
                if selectedGame == .soundVoltex {
                    SDVXImportView()
                } else {
                    ImportView()
                }
            }
            .presentationDetents([.large])
            .interactiveDismissDisabled()
            .automaticNavigationTransition(id: "ImportSheet", in: importNamespace)
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
    var unifiedHeader: some View {
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
            if selectedGame.supportsProfile {
                ProfileHeaderView()
                    .padding(.horizontal)
                    .padding(.top, 16.0)
            }
            AnalyticsView(model: analyticsModel,
                          isEditing: $isEditingAnalytics,
                          analyticsNamespace: analyticsNamespace,
                          towerNamespace: towerNamespace)
            .frame(minHeight: 360.0)
        }
        .padding(.bottom, 8.0)
    }

    @ViewBuilder
    var sdvxHeader: some View {
        VStack(spacing: 0.0) {
            SDVXProfileHeaderView()
                .padding(.horizontal)
            SDVXAnalyticsView(model: sdvxAnalyticsModel)
                .frame(minHeight: 360.0)
        }
        .padding(.bottom, 8.0)
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
            if selectedGame == .soundVoltex {
                Section("Shared.SDVX.Version") {
                    Picker("Shared.SDVX.Version", selection: $sdvxVersion) {
                        ForEach(SDVXVersion.supportedVersions, id: \.self) { version in
                            Text(version.marketingName).tag(version)
                        }
                    }
                    .pickerStyle(.inline)
                }
                .labelsVisibility(.visible)
            } else {
                Section("Shared.IIDX.Version") {
                    Picker("Shared.IIDX.Version", selection: $iidxVersion) {
                        ForEach(IIDXVersion.supportedVersions.reversed(), id: \.self) { version in
                            Text(version.marketingName).tag(version)
                        }
                    }
                    .pickerStyle(.inline)
                }
                .labelsVisibility(.visible)
            }
        } label: {
            HStack(spacing: 4.0) {
                Text(selectedGame.displayName)
                    .fontWeight(.bold)
                Image(systemName: "chevron.down")
                    .font(.caption2.bold())
            }
        }
        .menuActionDismissBehavior(.disabled)
    }
}
