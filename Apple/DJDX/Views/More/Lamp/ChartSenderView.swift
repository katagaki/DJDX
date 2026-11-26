import SwiftUI

struct ChartSenderView: View {

    @Environment(\.dismiss) private var dismiss

    let message: [UInt8]
    private let bits: [Bool]
    private let pairingNumber: String
    @State private var startDate = Date()
    @State private var previousBrightness: CGFloat?

    init(message: [UInt8]) {
        self.message = message
        bits = ChartCodec.chart(for: message) ?? []
        pairingNumber = ChartCodec.pairingNumber(for: message)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                ChartPlayfield.draw(in: &context, size: size, bits: bits,
                                    time: timeline.date.timeIntervalSince(startDate))
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            HStack(spacing: 12) {
                Button(role: .close) {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lamp.PairingNumber.\(pairingNumber)")
                        .font(.headline.monospacedDigit())
                    Text("Lamp.Send.Hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
        }
        .background(.black)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            startDate = Date()
            UIApplication.shared.isIdleTimerDisabled = true
            if let screen = currentScreen {
                previousBrightness = screen.brightness
                screen.brightness = 1.0
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            if let previousBrightness, let screen = currentScreen {
                screen.brightness = previousBrightness
            }
        }
    }

    private var currentScreen: UIScreen? {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first
    }
}
