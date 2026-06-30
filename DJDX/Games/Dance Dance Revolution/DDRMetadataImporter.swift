import Foundation
import SQLite
import SwiftSoup

actor DDRMetadataImporter {

    // swiftlint:disable:next type_name
    typealias DB = DDRMetadataDatabase

    func reloadBemaniWikiData(version: DDRVersion = .world) async -> Int {
        var metas: [DDRSongMeta] = []
        if let html = await fetchPage(version.bemaniWikiOldSongsPageURL()) {
            metas.append(contentsOf: parseSongs(from: html, baseVersion: nil))
        }
        if let html = await fetchPage(version.bemaniWikiNewSongsPageURL()) {
            metas.append(contentsOf: parseSongs(from: html, baseVersion: DDRVersion.worldVersionNumber))
        }
        replaceAll(with: metas)
        return metas.count
    }

    private func fetchPage(_ url: URL) async -> String? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return String(bytes: data, encoding: .utf8)
    }

    func parseSongs(from html: String, baseVersion: Int?) -> [DDRSongMeta] {
        guard let document = try? SwiftSoup.parse(html),
              let body = document.body(),
              let tables = try? body.select("table") else {
            return []
        }
        var result: [DDRSongMeta] = []
        var versionIndex = 0
        for table in tables {
            guard let rows = try? table.select("tr") else { continue }
            for row in rows {
                guard let cells = try? row.select("td, th") else { continue }
                let count = cells.count
                if count == 1 {
                    if let text = try? cells.first()?.text(), isVersionHeader(text) {
                        versionIndex += 1
                    }
                    continue
                }
                guard count >= 14 else { continue }
                let texts = cells.array().map { (try? $0.text()) ?? "" }
                let title = texts[count - 14].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { continue }
                let levels = Array(texts[(count - 9)...])
                result.append(DDRSongMeta(
                    title: title,
                    version: baseVersion ?? versionIndex,
                    levelStrings: levels
                ))
            }
        }
        return result
    }

    private func isVersionHeader(_ text: String) -> Bool {
        text.contains("DDR") || text.contains("DanceDance")
    }

    private func replaceAll(with metas: [DDRSongMeta]) {
        guard let database = try? DB.shared.getWriteConnection() else { return }
        _ = try? database.run(DB.songMetaTable.delete())
        try? database.transaction {
            for meta in metas {
                _ = try? database.run(DB.songMetaTable.insert(or: .replace,
                    DB.smTitleCompact <- meta.titleCompact(),
                    DB.smTitle <- meta.title,
                    DB.smVersion <- meta.version,
                    DB.smSPBeginner <- meta.spBeginner,
                    DB.smSPBasic <- meta.spBasic,
                    DB.smSPDifficult <- meta.spDifficult,
                    DB.smSPExpert <- meta.spExpert,
                    DB.smSPChallenge <- meta.spChallenge,
                    DB.smDPBasic <- meta.dpBasic,
                    DB.smDPDifficult <- meta.dpDifficult,
                    DB.smDPExpert <- meta.dpExpert,
                    DB.smDPChallenge <- meta.dpChallenge
                ))
            }
        }
    }

    func songMetaCount() -> Int {
        guard let database = try? DB.shared.getReadConnection() else { return 0 }
        return (try? database.scalar(DB.songMetaTable.count)) ?? 0
    }

    static func meta(from row: Row) -> DDRSongMeta {
        let meta = DDRSongMeta()
        meta.title = row[DB.smTitle]
        meta.version = row[DB.smVersion]
        meta.spBeginner = row[DB.smSPBeginner]
        meta.spBasic = row[DB.smSPBasic]
        meta.spDifficult = row[DB.smSPDifficult]
        meta.spExpert = row[DB.smSPExpert]
        meta.spChallenge = row[DB.smSPChallenge]
        meta.dpBasic = row[DB.smDPBasic]
        meta.dpDifficult = row[DB.smDPDifficult]
        meta.dpExpert = row[DB.smDPExpert]
        meta.dpChallenge = row[DB.smDPChallenge]
        return meta
    }
}
