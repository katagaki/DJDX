import SwiftUI

struct ProgressCard: View {

    @Environment(\.colorScheme) var colorScheme

    let title: String
    let message: String
    let percentage: Int

    var body: some View {
        ZStack(alignment: .center) {
            Color.black.opacity(colorScheme == .dark ? 0.5 : 0.2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .center, spacing: 0.0) {
                VStack(alignment: .center, spacing: 10.0) {
                    Text(LocalizedStringKey(title))
                        .bold()
                        .multilineTextAlignment(.center)
                    ProgressView(value: min(Float(percentage), 100.0), total: 100.0)
                        .progressViewStyle(.linear)
                    Text(NSLocalizedString(message, comment: "")
                        .replacingOccurrences(of: "%1", with: String(percentage)))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(.thickMaterial)
            .clipShape(.rect(cornerRadius: 16.0))
            .padding(.all, 32.0)
        }
        .ignoresSafeArea(.all)
    }
}

extension View {
    @ViewBuilder
    func progressOverlay(_ reporter: ProgressReporter) -> some View {
        overlay {
            if reporter.isShowing {
                ProgressCard(
                    title: reporter.title,
                    message: reporter.message,
                    percentage: reporter.percentage
                )
            } else {
                // HACK: DO NOT REMOVE. Removing this will cause a freeze when isShowing is false.
                Color.clear
            }
        }
    }
}
