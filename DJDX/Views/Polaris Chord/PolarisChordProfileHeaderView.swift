import SwiftUI
import UIKit

struct PolarisChordProfileHeaderView: View {

    @AppStorage(wrappedValue: PolarisChordVersion.polarisChord, "Global.PolarisChord.Version")
    var polarisChordVersion: PolarisChordVersion

    @State var playerName: String?
    @State var title: String?
    @State var paClass: String?
    @State var paSkill: String?
    @State var paClassImage: UIImage?
    @State var paSkillImage: UIImage?

    let profileHeight: CGFloat = 60.0
    let paSkillIconHeight: CGFloat = 24.0

    var hasData: Bool {
        playerName != nil || title != nil || paClass != nil || paSkill != nil
    }

    var body: some View {
        ZStack {
            if hasData {
                HStack(alignment: .center, spacing: 12.0) {
                    VStack(alignment: .leading, spacing: 2.0) {
                        if let playerName {
                            Text(verbatim: playerName)
                                .font(.title2)
                                .fontDesign(.rounded)
                                .fontWeight(.bold)
                                .lineLimit(1)
                        }
                        if let title {
                            Text(verbatim: title)
                                .fontDesign(.rounded)
                                .foregroundStyle(.secondary)
                                .fontWeight(.bold)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0.0)
                    if let paClass {
                        statBlock(label: "Shared.PolarisChord.PAClass", value: paClass, icon: paClassImage)
                    }
                    if let paSkill {
                        statBlock(label: "Shared.PolarisChord.PASkill", value: paSkill, icon: paSkillImage)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: profileHeight)
            }
        }
        .task {
            loadCachedProfile()
        }
        .onChange(of: polarisChordVersion) { _, _ in
            loadCachedProfile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await refreshProfile() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileRefreshRequested)) { _ in
            Task { await refreshProfile() }
        }
    }

    @ViewBuilder
    func statBlock(label: LocalizedStringKey, value: String, icon: UIImage? = nil) -> some View {
        VStack(spacing: 6.0) {
            Text(label)
                .font(.caption.weight(.bold))
                .italic()
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            HStack(spacing: 4.0) {
                if let icon {
                    Image(uiImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(height: paSkillIconHeight)
                }
                Text(verbatim: value)
                    .font(.title3.bold())
                    .fontWidth(.condensed)
                    .italic()
                    .monospacedDigit()
            }
            .frame(height: 24.0, alignment: .center)
        }
        .frame(minWidth: 64.0)
        .padding(.vertical, 8.0)
        .padding(.horizontal, 10.0)
        .cardBackground(cornerRadius: 8.0)
    }

    // The profile is rendered client-side from the same JSON API as the score
    // list, so the raw HTML has no values; POST to it for usr_profile / usr_nametag.
    func refreshProfile() async {
        var request = URLRequest(url: polarisChordVersion.playDataEndpointURL())
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "service_kind=profile&pdata_kind=profile".data(using: .utf8)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataDict = root["data"] as? [String: Any],
                  let playData = dataDict["play_data"] as? [String: Any] else { return }

            if let profile = playData["usr_profile"] as? [String: Any] {
                if let name = profile["usr_name"] as? String, !name.isEmpty {
                    UserDefaults.standard.set(name, forKey: "PolarisChordProfile.PlayerName")
                    await MainActor.run { self.playerName = name }
                }
                if let classText = Self.stringValue(profile["pa_class"]) {
                    UserDefaults.standard.set(classText, forKey: "PolarisChordProfile.PAClass")
                    await MainActor.run { self.paClass = classText }
                    await downloadPAClassIcon()
                }
                if let skillText = Self.stringValue(profile["pa_skill"]) {
                    UserDefaults.standard.set(skillText, forKey: "PolarisChordProfile.PASkill")
                    await MainActor.run { self.paSkill = skillText }
                    await downloadPASkillIcon(forSkill: Double(skillText) ?? 0.0)
                }
            }
            if let nametag = playData["usr_nametag"] as? [String: Any],
               let titleText = (nametag["set_title_name"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !titleText.isEmpty {
                UserDefaults.standard.set(titleText, forKey: "PolarisChordProfile.Title")
                await MainActor.run { self.title = titleText }
            }
        } catch {
            return
        }
    }

    // pa_class arrives as a number, pa_skill as a string.
    static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String { return string.isEmpty ? nil : string }
        if let int = value as? Int { return String(int) }
        if let double = value as? Double { return String(double) }
        return nil
    }

    // PA SKILL rate tier, mirroring get_pa_skill_icon() in index_init.js. The
    // sub-1.00 tier uses none.png; the rest are A.png ... K.png.
    // swiftlint:disable:next cyclomatic_complexity
    func paSkillIconName(forSkill skill: Double) -> String {
        switch skill {
        case ..<1.00: return "none"
        case ..<3.00: return "A"
        case ..<6.00: return "B"
        case ..<9.00: return "C"
        case ..<11.00: return "D"
        case ..<12.00: return "E"
        case ..<13.00: return "F"
        case ..<14.00: return "G"
        case ..<15.00: return "H"
        case ..<15.50: return "I"
        case ..<16.00: return "J"
        default: return "K"
        }
    }

    func paSkillIconURL(forSkill skill: Double) -> URL? {
        let name = paSkillIconName(forSkill: skill)
        return URL(string: """
https://eacache.s.konaminet.jp/game/polarischord/\(polarisChordVersion.slug)/img/playdata/paskill/\(name).png
""")
    }

    func downloadPASkillIcon(forSkill skill: Double) async {
        guard let url = paSkillIconURL(forSkill: skill),
              let image = await downloadImage(from: url) else { return }
        saveImage(image.1, named: "PolarisChordProfile.PASkillIcon.png")
        await MainActor.run { withAnimation { self.paSkillImage = image.0 } }
    }

    func downloadPAClassIcon() async {
        guard let url = URL(string: """
https://eacache.s.konaminet.jp/game/polarischord/\(polarisChordVersion.slug)/img/playdata/profile/icn_star.png
"""), let image = await downloadImage(from: url) else { return }
        saveImage(image.1, named: "PolarisChordProfile.PAClassIcon.png")
        await MainActor.run { withAnimation { self.paClassImage = image.0 } }
    }

    func downloadImage(from url: URL) async -> (UIImage, Data)? {
        guard let (data, response) = try? await URLSession.shared.data(for: URLRequest(url: url)),
              let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let image = UIImage(data: data) else { return nil }
        return (image, data)
    }

    func loadCachedProfile() {
        playerName = UserDefaults.standard.string(forKey: "PolarisChordProfile.PlayerName")
        title = UserDefaults.standard.string(forKey: "PolarisChordProfile.Title")
        paClass = UserDefaults.standard.string(forKey: "PolarisChordProfile.PAClass")
        paSkill = UserDefaults.standard.string(forKey: "PolarisChordProfile.PASkill")
        paClassImage = loadCachedImage(named: "PolarisChordProfile.PAClassIcon.png")
        paSkillImage = loadCachedImage(named: "PolarisChordProfile.PASkillIcon.png")
    }

    func imageFileURL(named fileName: String) -> URL? {
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return nil }
        return documentsDirectory.appendingPathComponent(fileName)
    }

    func loadCachedImage(named fileName: String) -> UIImage? {
        guard let fileURL = imageFileURL(named: fileName),
              FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return UIImage(contentsOfFile: fileURL.path)
    }

    func saveImage(_ imageData: Data, named fileName: String) {
        guard let fileURL = imageFileURL(named: fileName) else { return }
        try? imageData.write(to: fileURL)
    }
}
