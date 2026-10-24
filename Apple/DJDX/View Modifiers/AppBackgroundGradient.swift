import SwiftUI

struct AppBackgroundGradient: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(wrappedValue: Game.iidxArcade, "Global.SelectedGame") var selectedGame: Game
    @AppStorage(wrappedValue: IIDXVersion.zinrai, "Global.IIDX.Version") var iidxVersion: IIDXVersion
    @AppStorage(wrappedValue: SDVXVersion.nabla, "Global.SDVX.Version") var sdvxVersion: SDVXVersion
    @AppStorage(wrappedValue: PolarisChordVersion.polarisChord, "Global.PolarisChord.Version")
    var polarisChordVersion: PolarisChordVersion
    @AppStorage(wrappedValue: DDRVersion.world, "Global.DDR.Version") var ddrVersion: DDRVersion

    var accentColor: Color {
        selectedGame.accentColor(
            iidxVersion: iidxVersion,
            sdvxVersion: sdvxVersion,
            polarisChordVersion: polarisChordVersion,
            ddrVersion: ddrVersion
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.backgroundGradientTop, .backgroundGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                colors: selectedGame.backgroundGradientColors(
                    accentColor: accentColor, colorScheme: colorScheme
                ),
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    func appBackgroundGradient() -> some View {
        ZStack {
            AppBackgroundGradient()
            self
        }
    }
}
