import SwiftUI

struct ProgressDonut: View {

    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 3.0)
            Circle()
                .trim(from: 0.0, to: max(0.0, min(progress, 1.0)))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3.0, lineCap: .round))
                .rotationEffect(.degrees(-90.0))
        }
        .frame(width: 20.0, height: 20.0)
        .animation(.smooth, value: progress)
    }
}
