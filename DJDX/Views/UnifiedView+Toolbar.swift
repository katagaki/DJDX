import SwiftUI

extension UnifiedView {

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
