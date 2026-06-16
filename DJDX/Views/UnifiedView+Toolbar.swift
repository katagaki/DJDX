import SwiftUI

extension UnifiedView {

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
            if showAnalytics {
                PolarisChordAnalyticsView(model: polarisChordAnalyticsModel,
                                          isEditing: $isEditingAnalytics,
                                          analyticsNamespace: polarisChordAnalyticsNamespace)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.bottom, 8.0)
        .animation(.snappy, value: showProfileHeader)
        .animation(.smooth.speed(2.0), value: showAnalytics)
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
                } else if selectedGame == .danceDanceRevolution {
                    Picker("Shared.Version", selection: $ddrVersion) {
                        ForEach(DDRVersion.supportedVersions, id: \.self) { version in
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
                if let icon = selectedGame.iconResource {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
                Text(selectedGame.shortName)
                    .fontWeight(.bold)
                    .tint(.primary)
                Image(systemName: "chevron.down.circle.fill")
                    .font(.caption2.bold())
                    .symbolRenderingMode(.hierarchical)
                    .tint(.secondary)
            }
        }
    }
}
