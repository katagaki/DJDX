//
//  ImportView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Komponents
import SwiftUI

struct ImportView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.openURL) var openURL
    @EnvironmentObject var navigationManager: NavigationManager

    @State var isSelectingCSVFile: Bool = false

    var body: some View {
        NavigationStack(path: $navigationManager.importerTabPath) {
            VStack(spacing: 16.0) {
                ActionButton(text: "CSVをダウンロード",
                             icon: "safari",
                             isPrimary: true) {
                    openURL(URL(string: "https://p.eagate.573.jp/game/2dx/31/djdata/score_download.html")!)
                }
                             .foregroundStyle(.text)
                ActionButton(text: "CSVを読み込む",
                             icon: "square.and.arrow.down",
                             isPrimary: true) {
                    isSelectingCSVFile = true
                }
                             .foregroundStyle(.text)
                ActionButton(text: "サンプルデータを書き込む",
                             icon: "sparkles",
                             isPrimary: false) {
                    loadCSVData()
                }
            }
            .padding()
        }
        .sheet(isPresented: $isSelectingCSVFile) {
            DocumentPicker(allowedUTIs: [.commaSeparatedText], onDocumentPicked: { url in
                let isAccessSuccessful = url.startAccessingSecurityScopedResource()
                if isAccessSuccessful {
                    loadCSVData(from: url)
                } else {
                    url.stopAccessingSecurityScopedResource()
                }
            })
            .ignoresSafeArea(edges: [.bottom])
        }
    }

    func loadCSVData(from url: URL? = Bundle.main.url(forResource: "SampleData", withExtension: "csv")) {
        if let urlOfData: URL = url, let stringFromData: String = try? String(contentsOf: urlOfData) {
            let parsedCSV = CSwiftV(with: stringFromData)
            if let keyedRows = parsedCSV.keyedRows {
                try? modelContext.delete(model: EPOLISSongRecord.self)
                for keyedRow in keyedRows {
                    let scoreForSong: EPOLISSongRecord = EPOLISSongRecord(csvRowData: keyedRow)
                    modelContext.insert(scoreForSong)
                }
            }
        }
    }
}

#Preview {
    ImportView()
}
