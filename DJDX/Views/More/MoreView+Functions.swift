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

    func downloadStatusPageData() async {
        let baseURLString = "https://p.eagate.573.jp"
        let request = URLRequest(url: iidxVersion.statusPageURL())

        do {
            let (htmlData, _) = try await URLSession.shared.data(for: request)
            guard let htmlString = String(data: htmlData, encoding: .utf8) else { return }

            let document = try SwiftSoup.parse(htmlString)

            // Download Qpro image
            if let imgElement = try document.select("div.qpro-img img").first() {
                let extractedPath = try imgElement.attr("src")
                if let imageURL = URL(string: baseURLString + extractedPath) {
                    let imageRequest = URLRequest(url: imageURL)
                    let (imageData, response) = try await URLSession.shared.data(for: imageRequest)

                    if let httpResponse = response as? HTTPURLResponse,
                       (200...299).contains(httpResponse.statusCode) {
                        #if DEBUG
                        debugPrint("Qpro image downloaded")
                        #endif

                        if let documentsDirectory = FileManager.default.urls(
                            for: .documentDirectory, in: .userDomainMask
                        ).first {
                            let fileURL = documentsDirectory.appendingPathComponent("Qpro.png")
                            try? imageData.write(to: fileURL)
                        }
                    }
                }
            }

            // Parse notes radar data
            let radarCategories = try document.select("div#notes div.rank-cat")
            for category in radarCategories {
                guard let spanElement = try category.select("span").first() else { continue }
                let playTypeLabel = try spanElement.text()

                let listItems = try category.select("ul li")
                var values: [String: Double] = [:]
                for item in listItems {
                    let paragraphs = try item.select("p")
                    if paragraphs.size() == 2 {
                        let key = try paragraphs.get(0).text()
                        let valueString = try paragraphs.get(1).text()
                        if let value = Double(valueString) {
                            values[key] = value
                        }
                    }
                }

                let radarData = RadarData(
                    notes: values["NOTES"] ?? 0.0,
                    chord: values["CHORD"] ?? 0.0,
                    peak: values["PEAK"] ?? 0.0,
                    charge: values["CHARGE"] ?? 0.0,
                    scratch: values["SCRATCH"] ?? 0.0,
                    soflan: values["SOF-LAN"] ?? 0.0
                )

                if playTypeLabel == "SP" {
                    spRadarData = radarData
                } else if playTypeLabel == "DP" {
                    dpRadarData = radarData
                }
            }

            saveRadarData()
        } catch {
            return
        }
    }

    func saveRadarData() {
        let defaults = UserDefaults.standard
        if let spData = spRadarData {
            defaults.set(spData.notes, forKey: "NotesRadar.SP.Notes")
            defaults.set(spData.chord, forKey: "NotesRadar.SP.Chord")
            defaults.set(spData.peak, forKey: "NotesRadar.SP.Peak")
            defaults.set(spData.charge, forKey: "NotesRadar.SP.Charge")
            defaults.set(spData.scratch, forKey: "NotesRadar.SP.Scratch")
            defaults.set(spData.soflan, forKey: "NotesRadar.SP.Soflan")
        }
        if let dpData = dpRadarData {
            defaults.set(dpData.notes, forKey: "NotesRadar.DP.Notes")
            defaults.set(dpData.chord, forKey: "NotesRadar.DP.Chord")
            defaults.set(dpData.peak, forKey: "NotesRadar.DP.Peak")
            defaults.set(dpData.charge, forKey: "NotesRadar.DP.Charge")
            defaults.set(dpData.scratch, forKey: "NotesRadar.DP.Scratch")
            defaults.set(dpData.soflan, forKey: "NotesRadar.DP.Soflan")
        }
    }

    func loadRadarData() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "NotesRadar.SP.Notes") != nil {
            spRadarData = RadarData(
                notes: defaults.double(forKey: "NotesRadar.SP.Notes"),
                chord: defaults.double(forKey: "NotesRadar.SP.Chord"),
                peak: defaults.double(forKey: "NotesRadar.SP.Peak"),
                charge: defaults.double(forKey: "NotesRadar.SP.Charge"),
                scratch: defaults.double(forKey: "NotesRadar.SP.Scratch"),
                soflan: defaults.double(forKey: "NotesRadar.SP.Soflan")
            )
        }
        if defaults.object(forKey: "NotesRadar.DP.Notes") != nil {
            dpRadarData = RadarData(
                notes: defaults.double(forKey: "NotesRadar.DP.Notes"),
                chord: defaults.double(forKey: "NotesRadar.DP.Chord"),
                peak: defaults.double(forKey: "NotesRadar.DP.Peak"),
                charge: defaults.double(forKey: "NotesRadar.DP.Charge"),
                scratch: defaults.double(forKey: "NotesRadar.DP.Scratch"),
                soflan: defaults.double(forKey: "NotesRadar.DP.Soflan")
            )
        }
    }
}
