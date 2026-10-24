import SwiftUI

struct OnboardingView: View {

    var onContinue: () -> Void

    private let appName = "DJDX"

    private var welcomeTitle: Text {
        let format = String(localized: "Onboarding.Title")
        let accent = Text(appName).foregroundStyle(.accent)
        let parts = format.components(separatedBy: "%@")
        guard parts.count == 2 else { return accent }
        return Text(parts[0]) + accent + Text(parts[1])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16.0) {
                welcomeTitle
                    .fontWeight(.black)
                    .font(.largeTitle)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24.0)
                Spacer()
                VStack(alignment: .leading, spacing: 32.0) {
                    FeatureRow(
                        symbol: "arrow.down.circle.dotted",
                        tint: .red,
                        title: "Onboarding.Feature.WebImport.Title",
                        blurb: "Onboarding.Feature.WebImport.Blurb"
                    )
                    FeatureRow(
                        symbol: "externaldrive.connected.to.line.below.fill",
                        tint: .yellow,
                        title: "Onboarding.Feature.ExternalData.Title",
                        blurb: "Onboarding.Feature.ExternalData.Blurb"
                    )
                    FeatureRow(
                        symbol: "gamecontroller.fill",
                        tint: Color(red: 1.0, green: 0.35, blue: 0.7),
                        title: "Onboarding.Feature.MultipleGames.Title",
                        blurb: "Onboarding.Feature.MultipleGames.Blurb"
                    )
                    FeatureRow(
                        symbol: "camera.fill",
                        tint: .accent,
                        title: "Onboarding.Feature.Sessions.Title",
                        blurb: "Onboarding.Feature.Sessions.Blurb"
                    )
                }
                Spacer()
            }
            .padding(18.0)
        }
        .background {
            LinearGradient(
                colors: [.accent.opacity(0.12), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom, spacing: 0.0) {
            VStack(spacing: 12.0) {
                continueButton
            }
            .padding()
        }
        .interactiveDismissDisabled()
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private var continueButton: some View {
        let label = Text("Onboarding.Continue")
            .fontWeight(.bold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6.0)
        if #available(iOS 26.0, *) {
            Button(action: onContinue) { label }
                .clipShape(.capsule)
                .tint(.accent)
                .buttonStyle(.glassProminent)
        } else {
            Button(action: onContinue) { label }
                .clipShape(.capsule)
                .tint(.accent)
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct FeatureRow: View {

    var symbol: String
    var tint: Color
    var title: LocalizedStringKey
    var blurb: LocalizedStringKey

    var body: some View {
        HStack(alignment: .center, spacing: 16.0) {
            Image(systemName: symbol)
                .font(.system(size: 40.0))
                .foregroundStyle(tint)
                .frame(width: 56.0, height: 56.0)
            VStack(alignment: .leading, spacing: 6.0) {
                Text(title)
                    .fontWeight(.bold)
                Text(blurb)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0.0)
        }
    }
}

extension OnboardingView {
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    static func shouldShow(currentVersion: String, lastSeenVersion: String) -> Bool {
        guard let current = majorMinor(currentVersion) else { return false }
        guard let last = majorMinor(lastSeenVersion) else { return true }
        if current.major != last.major { return current.major > last.major }
        return current.minor > last.minor
    }

    static func majorMinor(_ version: String) -> (major: Int, minor: Int)? {
        let components = version.split(separator: ".")
        guard let major = components.first.flatMap({ Int($0) }) else { return nil }
        let minor = components.count > 1 ? (Int(components[1]) ?? 0) : 0
        return (major, minor)
    }
}
