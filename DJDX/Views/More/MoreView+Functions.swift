//
//  MoreView+Functions.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/02/20.
//

import Foundation
import SwiftSoup
import UIKit
import WebKit

extension MoreView {
    func loadQproImage() -> UIImage? {
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return nil }
        let fileURL = documentsDirectory.appendingPathComponent("Qpro.png")

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return UIImage(contentsOfFile: fileURL.path)
        } else {
            #if DEBUG
            debugPrint("Qpro image not found")
            #endif
            return nil
        }
    }

    func downloadQproImage() async {
        let baseURLString = "https://p.eagate.573.jp"
        let profileURLString = "\(baseURLString)/game/2dx/33/djdata/status.html"
        let request = URLRequest(url: URL(string: profileURLString)!)

        do {
            let (htmlData, _) = try await URLSession.shared.data(for: request)
            guard let htmlString = String(data: htmlData, encoding: .utf8) else { return }

            let document = try SwiftSoup.parse(htmlString)
            guard let imgElement = try document.select("div.qpro-img img").first() else { return }

            let extractedPath = try imgElement.attr("src")
            guard let imageURL = URL(string: baseURLString + extractedPath) else { return }

            let imageRequest = URLRequest(url: imageURL)
            let (imageData, response) = try await URLSession.shared.data(for: imageRequest)

            guard let httpResponse = response as? HTTPURLResponse,
                    (200...299).contains(httpResponse.statusCode) else { return }

            #if DEBUG
            debugPrint("Qpro image downloaded")
            #endif

            guard let documentsDirectory = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first else { return }
            let fileURL = documentsDirectory.appendingPathComponent("Qpro.png")

            try? imageData.write(to: fileURL)
        } catch {
            return
        }
    }
}
