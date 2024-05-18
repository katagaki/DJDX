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
    @Query(sort: \EPOLISSongRecord.title) var items: [EPOLISSongRecord]

    @State var isSelectingCSVFile: Bool = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4.0) {
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text(item.genre)
                                .font(.caption2)
                                .fontWidth(.condensed)
                                .foregroundStyle(.secondary)
                            Text(item.title)
                                .bold()
                                .fontWidth(.condensed)
                            Text(item.artist)
                                .font(.caption2)
                                .fontWidth(.condensed)
                        }
                        HStack(alignment: .top) {
                            Spacer()
                            Group {
                                if item.beginnerScore.difficulty != 0 {
                                    VStack {
                                        Text(String(item.beginnerScore.difficulty))
                                            .italic()
                                            .fontWidth(.standard)
                                            .fontWeight(.black)
                                        Text(verbatim: "BEGINNER")
                                            .font(.caption2)
                                            .fontWidth(.expanded)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(.green)
                                }
                                if item.normalScore.difficulty != 0 {
                                    VStack {
                                        Text(String(item.normalScore.difficulty))
                                            .italic()
                                            .fontWidth(.standard)
                                            .fontWeight(.black)
                                        Text(verbatim: "NORMAL")
                                            .font(.caption2)
                                            .fontWidth(.expanded)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(.blue)
                                }
                                if item.hyperScore.difficulty != 0 {
                                    VStack {
                                        Text(String(item.hyperScore.difficulty))
                                            .italic()
                                            .fontWidth(.standard)
                                            .fontWeight(.black)
                                        Text(verbatim: "HYPER")
                                            .font(.caption2)
                                            .fontWidth(.expanded)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(.orange)
                                }
                                if item.anotherScore.difficulty != 0 {
                                    VStack {
                                        Text(String(item.anotherScore.difficulty))
                                            .italic()
                                            .fontWidth(.standard)
                                            .fontWeight(.black)
                                        Text(verbatim: "ANOTHER")
                                            .font(.caption2)
                                            .fontWidth(.expanded)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(.red)
                                }
                                if item.leggendariaScore.difficulty != 0 {
                                    VStack {
                                        Text(String(item.leggendariaScore.difficulty))
                                            .italic()
                                            .fontWidth(.standard)
                                            .fontWeight(.black)
                                        Text(verbatim: "LEGGENDARIA")
                                            .font(.caption2)
                                            .fontWidth(.expanded)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(.purple)
                                }
                            }
                            .kerning(-0.2)
                            .lineLimit(1)
                        }
                    }
                }
            }
            .navigationTitle("EPOLIS")
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
