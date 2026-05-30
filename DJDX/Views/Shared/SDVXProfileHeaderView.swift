//
//  SDVXProfileHeaderView.swift
//  DJDX
//
//  Created by Claude on 2026/05/30.
//

import SwiftSoup
import SwiftUI
import UIKit

struct SDVXProfileHeaderView: View {

    @AppStorage(wrappedValue: SDVXVersion.nabla, "Global.SDVX.Version") var sdvxVersion: SDVXVersion

    @State var apCardImage: UIImage?
    @State var playerName: String?
    @State var volforce: String?

    let profileHeight: CGFloat = 150.0

    var hasData: Bool {
        apCardImage != nil || playerName != nil || volforce != nil
    }

    var body: some View {
        ZStack {
            if hasData {
                HStack(alignment: .center, spacing: 12.0) {
                    if let apCardImage {
                        Image(uiImage: apCardImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: profileHeight)
                            .clipShape(.rect(cornerRadius: 8.0))
                    }
                    VStack(alignment: .leading, spacing: 6.0) {
                        if let playerName {
                            Text(verbatim: playerName)
                                .font(.headline)
                        }
                        if let volforce {
                            HStack(spacing: 4.0) {
                                Text("Analytics.SDVX.Volforce")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                Text(verbatim: volforce)
                                    .font(.title2.bold())
                                    .fontWidth(.expanded)
                                    .foregroundStyle(LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .top, endPoint: .bottom
                                    ))
                            }
                        }
                    }
                    Spacer(minLength: 0.0)
                }
                .frame(maxWidth: .infinity)
                .frame(height: profileHeight)
            }
        }
        .task {
            loadCachedProfile()
            await refreshProfile()
        }
        .onChange(of: sdvxVersion) { _, _ in
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
                if let imageURL = URL(string: src) {
                    let (imageData, response) = try await URLSession.shared.data(for: URLRequest(url: imageURL))
                    if let httpResponse = response as? HTTPURLResponse,
                       (200...299).contains(httpResponse.statusCode),
                       let image = UIImage(data: imageData) {
                        saveAPCardImage(imageData)
                        await MainActor.run { withAnimation { self.apCardImage = image } }
                    }
                }
            }

            // Player name
            if let nameElement = try document.select("#player_name p").first() {
                let name = try nameElement.text().trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    UserDefaults.standard.set(name, forKey: "SDVXProfile.PlayerName")
                    await MainActor.run { self.playerName = name }
                }
            }

            // VOLFORCE
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

    func loadCachedProfile() {
        apCardImage = loadCachedAPCardImage()
        playerName = UserDefaults.standard.string(forKey: "SDVXProfile.PlayerName")
        volforce = UserDefaults.standard.string(forKey: "SDVXProfile.Volforce")
    }

    func apCardImageFileURL() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return nil }
        return documentsDirectory.appendingPathComponent("APCard.png")
    }

    func loadCachedAPCardImage() -> UIImage? {
        guard let fileURL = apCardImageFileURL(),
              FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return UIImage(contentsOfFile: fileURL.path)
    }

    func saveAPCardImage(_ imageData: Data) {
        guard let fileURL = apCardImageFileURL() else { return }
        try? imageData.write(to: fileURL)
    }
}
