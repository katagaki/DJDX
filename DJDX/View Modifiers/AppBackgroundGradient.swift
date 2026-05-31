import SwiftUI

extension View {
    func appBackgroundGradient() -> some View {
        ZStack {
            LinearGradient(
                colors: [.backgroundGradientTop, .backgroundGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            self
        }
    }
}
