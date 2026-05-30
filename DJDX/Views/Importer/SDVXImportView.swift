//
//  SDVXImportView.swift
//  DJDX
//
//  Created by Claude on 2026/05/30.
//

import SwiftUI
import UniformTypeIdentifiers

struct SDVXImportView: View {

    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss
    @Environment(ProgressAlertManager.self) var progressAlertManager

    @AppStorage(wrappedValue: SDVXVersion.nabla, "Global.SDVX.Version") var sdvxVersion: SDVXVersion

    @State var importPath = NavigationPath()
    @State var importToDate: Date = .now
    @State var isAutoImportFailed: Bool = false
    @State var didImportSucceed: Bool = false
    @State var autoImportFailedReason: ImportFailedReason?
    @State var isSelectingCSVFile: Bool = false

    let importer = SDVXDataImporter()

    enum SDVXImportPath: Hashable {
        case web
    }

    var body: some View {
        NavigationStack(path: $importPath) {
            Color.clear
            .navigationTitle("ViewTitle.Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .close) { dismiss() }
                    } else {
                        Button { dismiss() } label: { Image(systemName: "xmark.circle") }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0.0) {
                bottomBar()
                    .contentShape(.rect)
                    .padding()
            }
            .alert(
                "Alert.Import.Success.Title",
                isPresented: $didImportSucceed,
                actions: {
                    Button("Shared.OK", role: .cancel) {
                        didImportSucceed = false
                        importPath = NavigationPath()
                    }
                },
                message: { Text("Alert.Import.Success.Subtitle") }
            )
            .alert(
                "Alert.Import.Error.Title",
                isPresented: $isAutoImportFailed,
                actions: {
                    Button("Shared.OK", role: .cancel) {
                        isAutoImportFailed = false
                        importPath = NavigationPath()
                    }
                },
                message: { Text(errorMessage(for: autoImportFailedReason ?? .serverError)) }
            )
            .onChange(of: didImportSucceed) { _, newValue in
                if newValue {
                    NotificationCenter.default.post(name: .dataImported, object: nil)
                }
            }
            .sheet(isPresented: $isSelectingCSVFile) {
                DocumentPicker(allowedUTIs: [.commaSeparatedText], onDocumentPicked: { urls in
                    importCSVs(from: urls)
                })
                .ignoresSafeArea(edges: [.bottom])
            }
            .navigationDestination(for: SDVXImportPath.self) { path in
                switch path {
                case .web:
                    SDVXWebImporter(importToDate: $importToDate,
                                    isAutoImportFailed: $isAutoImportFailed,
                                    didImportSucceed: $didImportSucceed,
                                    autoImportFailedReason: $autoImportFailedReason)
                }
            }
        }
    }

    @ViewBuilder
    func bottomBar() -> some View {
        HStack(spacing: 10.0) {
            Button {
                importPath.append(SDVXImportPath.web)
            } label: {
                VStack(spacing: 8.0) {
                    Image(systemName: "globe")
                        .font(.system(size: 24))
                        .frame(maxHeight: 30.0)
                    Text(.calendarImportFromWeb)
                        .fontWeight(.medium)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accent)
                .foregroundStyle(.white)
                .adaptiveClipShape()
            }
            Menu {
                Section {
                    Button(.importerCsvDownloadButton, systemImage: "safari") {
                        openURL(sdvxVersion.downloadPageURL())
                    }
                } header: {
                    Text("Importer.CSV.Download.Description")
                        .foregroundColor(.primary).textCase(nil).font(.body)
                }
                Section {
                    Button(.importerCsvLoadButton, systemImage: "folder") {
                        isSelectingCSVFile = true
                    }
                } header: {
                    Text("Importer.CSV.Load.Description")
                        .foregroundColor(.primary).textCase(nil).font(.body)
                }
            } label: {
                VStack(spacing: 8.0) {
                    Image(systemName: "document.badge.plus")
                        .font(.system(size: 24))
                        .frame(maxHeight: 30.0)
                    Text(.calendarImportFromCSV)
                        .fontWeight(.medium)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accent)
                .foregroundStyle(.white)
                .adaptiveClipShape()
            }
        }
    }

    func importCSVs(from urls: [URL]) {
        progressAlertManager.show(
            title: "Alert.Importing.Title",
            message: "Alert.Importing.Text"
        ) {
            Task { await performCSVImport(from: urls) }
        }
    }

    private func performCSVImport(from urls: [URL]) async {
        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let csvString = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for await progress in await importer.importCSV(
                csv: csvString,
                to: importToDate,
                version: sdvxVersion
            ) {
                if let current = progress.currentFileProgress,
                   let total = progress.currentFileTotal, total > 0 {
                    let percentage = (current * 100) / total
                    await MainActor.run { progressAlertManager.updateProgress(percentage) }
                }
            }
        }
        await MainActor.run {
            didImportSucceed = true
            progressAlertManager.hide()
        }
    }

    func errorMessage(for reason: ImportFailedReason) -> String {
        switch reason {
        case .noPremiumCourse: return NSLocalizedString("Alert.Import.Error.Subtitle.NoPremiumCourse", comment: "")
        case .noEAmusementPass: return NSLocalizedString("Alert.Import.Error.Subtitle.NoEAmusementPass", comment: "")
        case .noPlayData: return NSLocalizedString("Alert.Import.Error.Subtitle.NoPlayData", comment: "")
        case .serverError: return NSLocalizedString("Alert.Import.Error.Subtitle.ServerError", comment: "")
        case .maintenance: return NSLocalizedString("Alert.Import.Error.Subtitle.Maintenance", comment: "")
        }
    }
}
