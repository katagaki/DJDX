//
//  UnifiedView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/05/29.
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

    @AppStorage(wrappedValue: false, "Review.IsPrompted", store: .standard) var hasReviewBeenPrompted: Bool
    @AppStorage(wrappedValue: 0, "Review.LaunchCount", store: .standard) var launchCount: Int

    @State var selectedSegment: GameDestination = .analytics
    @State var isPresentingImport: Bool = false
    @State var isPresentingSettings: Bool = false
    @State var isFirstStartCleanupComplete: Bool = false

    var body: some View {
        @Bindable var progressAlertManager = progressAlertManager
        NavigationStack(path: $navigationManager.path) {
            ScoresView {
                unifiedHeader
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    gameMenu
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Shared.Import", systemImage: "arrow.down.circle.dotted") {
                        isPresentingImport = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tab.More", systemImage: "person.crop.circle") {
                        isPresentingSettings = true
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingImport) {
            ImportView()
        }
        .sheet(isPresented: $isPresentingSettings) {
            MoreView()
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
            if selectedGame.supportsProfile {
                ProfileHeaderView()
            }
            Picker("", selection: $selectedSegment) {
                ForEach(selectedGame.destinations) { destination in
                    Text(destination.titleKey).tag(destination)
                }
            }
            .pickerStyle(.segmented)
            Group {
                switch selectedSegment {
                case .analytics: AnalyticsView()
                case .tower: TowerView()
                case .activity: ActivityView()
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
