import SwiftSoup
import SwiftUI
import UIKit

struct SDVXProfileHeaderView: View {

    @AppStorage(wrappedValue: SDVXVersion.nabla, "Global.SDVX.Version") var sdvxVersion: SDVXVersion

    @State var apCardImage: UIImage?
    @State var playerName: String?
    @State var volforceImage: UIImage?
    @State var volforce: String?

    let profileHeight: CGFloat = 100.0
    let apCardHeight: CGFloat = 100.0
    let volforceImageHeight: CGFloat = 72.0

    var hasData: Bool {
        apCardImage != nil || playerName != nil || volforceImage != nil || volforce != nil
    }

    var body: some View {
        ZStack {
            if hasData {
                HStack(alignment: .center, spacing: 12.0) {
                    if let apCardImage {
                        Image(uiImage: apCardImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: apCardHeight)
                            .clipShape(.rect(cornerRadius: 8.0))
                    }
                    if let playerName {
                        Text(verbatim: playerName)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    } else {
                        Spacer(minLength: 0.0)
                    }
                    if volforceImage != nil || volforce != nil {
                        VStack(spacing: 4.0) {
                            if let volforceImage {
                                Image(uiImage: volforceImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: volforceImageHeight)
                            }
                            if let volforce {
                                Text(verbatim: volforce)
                                    .font(.title3.bold())
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: profileHeight)
            }
        }
        .task {
            loadCachedProfile()
        }
        .onChange(of: sdvxVersion) { _, _ in
            loadCachedProfile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await refreshProfile() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileRefreshRequested)) { _ in
            Task { await refreshProfile() }
        }
    }

    func refreshProfile() async {
        let request = URLRequest(url: sdvxVersion.profilePageURL())
        do {
            let (htmlData, _) = try await URLSession.shared.data(for: request)
            guard let htmlString = String(data: htmlData, encoding: .utf8) else { return }
            let document = try SwiftSoup.parse(htmlString)

            // APカード image
            if let imgElement = try document.select("#apcard img").first() {
                let src = try imgElement.attr("src")
                if let imageURL = URL(string: src),
                   let image = await downloadImage(from: imageURL) {
                    saveImage(image.1, named: "APCard.png")
                    await MainActor.run { withAnimation { self.apCardImage = image.0 } }
                }
            }

            // Player name (may span multiple <p> tags; join with newlines)
            let nameParagraphs = try document.select("#player_name p")
            let nameLines = try nameParagraphs.map { try $0.text().trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if !nameLines.isEmpty {
                let name = nameLines.joined(separator: "\n")
                UserDefaults.standard.set(name, forKey: "SDVXProfile.PlayerName")
                await MainActor.run { self.playerName = name }
            }

            // VOLFORCE icon (from the force_class element's id, e.g. force_06)
            if let forceClassElement = try document.select(".force_class").first() {
                let forceID = try forceClassElement.attr("id")
                let forceNumber = forceID.replacingOccurrences(of: "force_", with: "")
                if !forceNumber.isEmpty, let iconURL = volforceIconURL(for: forceNumber),
                   let image = await downloadImage(from: iconURL) {
                    saveImage(image.1, named: "VolforceIcon.png")
                    await MainActor.run { withAnimation { self.volforceImage = image.0 } }
                }
            }

            // VOLFORCE value
            if let forceElement = try document.select("#force_point").first() {
                let force = try forceElement.text().trimmingCharacters(in: .whitespaces)
                if !force.isEmpty {
                    UserDefaults.standard.set(force, forKey: "SDVXProfile.Volforce")
                    await MainActor.run { self.volforce = force }
                }
            }
        } catch {
            return
        }
    }

    func volforceIconURL(for number: String) -> URL? {
        URL(string: """
https://eacache.s.konaminet.jp/game/sdvx/\(sdvxVersion.slug)/images/playdata/profile/force_icon_\(number).png
""")
    }

    func downloadImage(from url: URL) async -> (UIImage, Data)? {
        guard let (data, response) = try? await URLSession.shared.data(for: URLRequest(url: url)),
              let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let image = UIImage(data: data) else { return nil }
        return (image, data)
    }

    func loadCachedProfile() {
        apCardImage = loadCachedImage(named: "APCard.png")
        volforceImage = loadCachedImage(named: "VolforceIcon.png")
        playerName = UserDefaults.standard.string(forKey: "SDVXProfile.PlayerName")
        volforce = UserDefaults.standard.string(forKey: "SDVXProfile.Volforce")
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
