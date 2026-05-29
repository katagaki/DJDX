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
    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var playTypeToShow: IIDXPlayType

    @AppStorage(wrappedValue: false, "Review.IsPrompted", store: .standard) var hasReviewBeenPrompted: Bool
    @AppStorage(wrappedValue: 0, "Review.LaunchCount", store: .standard) var launchCount: Int

    @State var selectedSegment: GameDestination = .analytics
    @State var isPresentingImport: Bool = false
    @State var isFirstStartCleanupComplete: Bool = false

    @State var analyticsModel = AnalyticsModel()

    @Namespace var importNamespace
    @Namespace var analyticsNamespace

    var body: some View {
        @Bindable var progressAlertManager = progressAlertManager
        NavigationStack(path: $navigationManager.path) {
            ScoresView {
                unifiedHeader
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    gameMenu
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Shared.Import", systemImage: "arrow.down.circle.dotted") {
                        isPresentingImport = true
                    }
                    .automaticMatchedTransitionSource(id: "ImportSheet", in: importNamespace)
                }
                ToolbarItem(placement: .topBarTrailing) {
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
        }
        .sheet(isPresented: $isPresentingImport) {
            ImportView()
                .presentationDetents([.medium, .large])
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
        .onChange(of: selectedGame) { _, newValue in
            if !newValue.destinations.contains(selectedSegment) {
                selectedSegment = newValue.destinations.first ?? .analytics
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
        VStack(spacing: 16.0) {
            VStack(spacing: 16.0) {
                if selectedGame.supportsPlayType {
                    Picker("Shared.PlayType", selection: $playTypeToShow) {
                        Text(verbatim: "SP")
                            .tag(IIDXPlayType.single)
                        Text(verbatim: "DP")
                            .tag(IIDXPlayType.double)
                    }
                    .pickerStyle(.segmented)
                }
                if selectedGame.supportsProfile {
                    ProfileHeaderView()
                }
                Picker("", selection: $selectedSegment) {
                    ForEach(selectedGame.destinations) { destination in
                        Text(destination.titleKey).tag(destination)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)
            Group {
                switch selectedSegment {
                case .analytics:
                    AnalyticsView(model: analyticsModel, analyticsNamespace: analyticsNamespace)
                case .tower:
                    TowerView()
                        .padding(.horizontal)
                case .activity:
                    ActivityView()
                        .padding(.horizontal)
                }
            }
            .frame(minHeight: 360.0)
        }
        .padding(.vertical, 8.0)
    }

    @ViewBuilder
    var gameMenu: some View {
        Menu {
            Section {
                ForEach(Game.allCases) { game in
                    Button {
                        selectedGame = game
                    } label: {
                        if selectedGame == game {
                            Label(game.displayName, systemImage: "checkmark")
                        } else {
                            Text(game.displayName)
                        }
                    }
                    .disabled(!game.isAvailable)
                }
            }
            Section("Shared.IIDX.Version") {
                Picker("Shared.IIDX.Version", selection: $iidxVersion) {
                    ForEach(IIDXVersion.supportedVersions.reversed(), id: \.self) { version in
                        Text(version.marketingName).tag(version)
                    }
                }
                .pickerStyle(.inline)
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
