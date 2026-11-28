import SwiftUI
import UIKit

struct PopnProfileHeaderView: View {

    @AppStorage(wrappedValue: PopnVersion.highCheers, "Global.Popn.Version") var popnVersion: PopnVersion

    @State var playerName: String?
    @State var popnClass: String?
    @State var popnClassImage: UIImage?
    @State var popnClassTier: PopnClass.Tier?

    let profileHeight: CGFloat = DesignMetrics.profileHeight
    let reader = PopnReader()

    var body: some View {
        ZStack {
            if playerName != nil || popnClass != nil {
                HStack(alignment: .center, spacing: 12.0) {
                    if let playerName {
                        Text(verbatim: playerName)
                            .font(.playline(size: 16.0))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0.0)
                    if let popnClass {
                        classBlock(value: popnClass)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: profileHeight)
            }
        }
        .task {
            await loadProfile()
        }
        .onChange(of: popnVersion) { _, _ in
            Task { await loadProfile() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await loadProfile() }
        }
    }

    @ViewBuilder
    func classBlock(value: String) -> some View {
        VStack(spacing: 4.0) {
            Text("Shared.Popn.PopnClass")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            HStack(spacing: 4.0) {
                if let popnClassImage {
                    Image(uiImage: popnClassImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 22.0)
                } else if let popnClassTier {
                    Text(verbatim: popnClassTier.name)
                        .font(.caption.bold())
                        .foregroundStyle(popnClassTier.color)
                }
                Text(verbatim: value)
                    .font(.scoreline(.callout))
            }
            .frame(height: 22.0, alignment: .center)
        }
        .frame(minWidth: 64.0)
        .fixedSize()
        .padding(.vertical, 6.0)
        .padding(.horizontal, 4.0)
    }

    func loadProfile() async {
        let version = popnVersion
        let profile = PopnProfile.load(for: version)
        var classText = profile.popnClass
        var tier: PopnClass.Tier?
        if classText == nil {
            let records = await reader.latestSongRecords(for: version)
            if !records.isEmpty {
                let value = PopnClass.value(for: records)
                classText = String(format: "%.2f", value)
                tier = PopnClass.tier(for: value)
            }
        }
        let image = await classImage(from: profile.popnClassIconURL, version: version)
        await MainActor.run {
            playerName = profile.playerName
            popnClass = classText
            popnClassTier = tier
            withAnimation { popnClassImage = image }
        }
    }

    func classImage(from urlString: String?, version: PopnVersion) async -> UIImage? {
        let fileURL = SharedContainer.imagesURL.appendingPathComponent("PopnProfile.\(version.slug).PopnClassIcon.png")
        let cachedURL = UserDefaults.standard.string(forKey: PopnProfile.key("PopnClassIconCachedURL", for: version))
        if let urlString, urlString == cachedURL,
           let image = UIImage(contentsOfFile: fileURL.path) {
            return image
        }
        guard let urlString, let url = URL(string: urlString) else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(for: URLRequest(url: url)),
              let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let image = UIImage(data: data) else {
            return UIImage(contentsOfFile: fileURL.path)
        }
        try? FileManager.default.createDirectory(at: SharedContainer.imagesURL, withIntermediateDirectories: true)
        try? data.write(to: fileURL)
        UserDefaults.standard.set(urlString, forKey: PopnProfile.key("PopnClassIconCachedURL", for: version))
        return image
    }
}
