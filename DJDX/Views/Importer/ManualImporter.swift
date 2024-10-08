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

    @Environment(ProgressAlertManager.self) var progressAlertManager

    @Binding var importToDate: Date
    @Binding var importPlayType: IIDXPlayType

    @State var isSelectingCSVFile: Bool = false
    @Binding var didImportSucceed: Bool

    @AppStorage(wrappedValue: IIDXVersion.pinkyCrush, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    var body: some View {
        List {
            Section {
                Button("Importer.CSV.Download.Button", systemImage: "safari") {
                    openURL(URL(string: "https://p.eagate.573.jp/game/2dx/31/djdata/score_download.html")!)
                }
            } header: {
                Text("Importer.CSV.Download.Description")
                    .foregroundColor(.primary)
                    .textCase(nil)
                    .font(.body)
            }
            Section {
                Button("Importer.CSV.Load.Button", systemImage: "folder") {
                    isSelectingCSVFile = true
                }
            } header: {
                Text("Importer.CSV.Load.Description")
                    .foregroundColor(.primary)
                    .textCase(nil)
                    .font(.body)
            }
        }
        .navigationTitle("ViewTitle.Importer.CSV")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isSelectingCSVFile) {
            DocumentPicker(allowedUTIs: [.commaSeparatedText], onDocumentPicked: { url in
                let isAccessSuccessful = url.startAccessingSecurityScopedResource()
                if isAccessSuccessful {
                    progressAlertManager.show(
                        title: "Alert.Importing.Title",
                        message: "Alert.Importing.Text"
                    ) {
                        Task.detached {
                            let actor = DataImporter(modelContainer: sharedModelContainer)
                            await actor.importCSV(
                                url: url,
                                to: importToDate,
                                for: .single,
                                from: iidxVersion
                            ) { currentProgress, totalProgress in
                                Task {
                                    let progress = (currentProgress * 100) / totalProgress
                                    await MainActor.run {
                                        progressAlertManager.updateProgress(
                                            progress
                                        )
                                    }
                                }
                            }
                            await MainActor.run {
                                didImportSucceed = true
                                progressAlertManager.hide()
                            }
                        }
                    }
                } else {
                    url.stopAccessingSecurityScopedResource()
                }
            })
            .ignoresSafeArea(edges: [.bottom])
        }
    }
}
