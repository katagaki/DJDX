//
//  ManualImporter.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/24.
//

import Komponents
import SwiftData
import SwiftUI

struct ManualImporter: View {

    @Environment(\.openURL) var openURL
    @Environment(\.modelContext) var modelContext

    @EnvironmentObject var calendar: CalendarManager

    @State var isSelectingCSVFile: Bool = false
    @Binding var didImportSucceed: Bool

    var body: some View {
        List {
            Section {
                Button("CSVをダウンロード", systemImage: "safari") {
                    openURL(URL(string: "https://p.eagate.573.jp/game/2dx/31/djdata/score_download.html")!)
                }
            } header: {
                Text("""
                まず、公式ウェブサイトからCSVファイルをダウンロードしてください。
                ダウンロードできない場合、Safariのメニューから「デスクトップサイト用Webサイトを表示」を選択してください。
                """)
                    .foregroundColor(.primary)
                    .textCase(nil)
                    .font(.body)
            }
            Section {
                Button("CSVを読み込む", systemImage: "folder") {
                    isSelectingCSVFile = true
                }
            } header: {
                Text("CSVファイルのダウンロードができたら、こちらで読み込んでください。")
                    .foregroundColor(.primary)
                    .textCase(nil)
                    .font(.body)
            }
            Section {
                Button("サンプルデータを読み込む", systemImage: "sparkles") {
                    loadCSVData()
                }
            } header: {
                Text("アプリを試したい場合、サンプルデータを読み込んでご利用いただけます。")
                .foregroundColor(.primary)
                .textCase(nil)
                .font(.body)
            }
        }
        .navigationTitle("CSVインポート")
        .navigationBarTitleDisplayMode(.inline)
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
                // Delete selected date's import group
                let fetchDescriptor = FetchDescriptor<ImportGroup>(
                    predicate: importGroups(in: calendar)
                    )
                if let importGroupsOnSelectedDate: [ImportGroup] = try? modelContext.fetch(fetchDescriptor) {
                    for importGroup in importGroupsOnSelectedDate {
                        modelContext.delete(importGroup)
                    }
                }
                // Create new import group for selected date
                let newImportGroup: ImportGroup = ImportGroup(importDate: calendar.selectedDate, iidxData: [])
                modelContext.insert(newImportGroup)
                try? modelContext.save()
                // Read song records
                for keyedRow in keyedRows {
                    let scoreForSong: IIDXSongRecord = IIDXSongRecord(csvRowData: keyedRow)
                    modelContext.insert(scoreForSong)
                    scoreForSong.importGroup = newImportGroup
                }
                try? modelContext.save()
                didImportSucceed = true
            }
        }
    }
}
