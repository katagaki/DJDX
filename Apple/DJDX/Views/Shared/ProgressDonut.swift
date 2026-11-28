import SwiftUI

struct ProgressDonut: View {

    let progress: Double
    var lineWidth: CGFloat = 3.0
    var tint: Color = .accentColor
    var size: CGFloat? = 20.0

    @State private var isSpinning: Bool = false

    private var clampedProgress: Double {
        max(0.0, min(progress, 1.0))
    }

    var body: some View {
        ZStack {
            Circle()
                .inset(by: lineWidth / 2.0)
                .stroke(tint.opacity(0.2), lineWidth: lineWidth)
            if clampedProgress > 0.0 {
                Circle()
                    .inset(by: lineWidth / 2.0)
                    .trim(from: 0.0, to: clampedProgress)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90.0))
                    .animation(.smooth, value: clampedProgress)
            } else {
                Circle()
                    .inset(by: lineWidth / 2.0)
                    .trim(from: 0.0, to: 0.25)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(isSpinning ? 270.0 : -90.0))
                    .onAppear {
                        isSpinning = false
                        withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                            isSpinning = true
                        }
                    }
            }
        }
        .frame(width: size, height: size)
    }
}
