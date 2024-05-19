//
//  ScoresView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/18.
//

import SwiftUI
import SwiftData

struct ScoresView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager

    @Query(sort: \EPOLISSongRecord.title) var songRecords: [EPOLISSongRecord]

    @State var isSelectingCSVFile: Bool = false

    var body: some View {
        NavigationStack(path: $navigationManager.scoresTabPath) {
            List {
                ForEach(songRecords) { songRecord in
                    NavigationLink(value: ViewPath.scoreViewer(songRecord: songRecord)) {
                        VStack(alignment: .leading, spacing: 4.0) {
                            VStack(alignment: .leading, spacing: 2.0) {
                                DetailedSongTitle(songRecord: songRecord)
                            }
                            HStack {
                                Spacer()
                                LevelShowcase(songRecord: songRecord)
                            }
                        }
                    }
                }
            }
            .navigationTitle("スコア一覧")
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            loadCSVData()
                        } label: {
                            Text("サンプルデータ")
                        }
                        Button {
                            isSelectingCSVFile = true
                        } label: {
                            Text("CSV")
                        }
                        Button {
                            try? modelContext.delete(model: EPOLISSongRecord.self)
                        } label: {
                            Text("クリア")
                                .foregroundStyle(.red)
                        }
                    }
                }
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
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .scoreViewer(let songRecord): ScoreViewer(songRecord: songRecord)
                default: Color.clear
                }
            }
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
