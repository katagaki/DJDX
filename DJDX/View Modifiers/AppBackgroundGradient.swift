import SwiftUI

struct AppBackgroundGradient: View {
    @AppStorage(wrappedValue: Game.iidxArcade, "Global.SelectedGame") var selectedGame: Game

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.backgroundGradientTop, .backgroundGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                colors: selectedGame.backgroundGradientColors,
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
