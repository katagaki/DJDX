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
    @State var importGroups: [SDVXImportGroupInfo] = []

    let importer = SDVXImporter()
    let fetcher = SDVXReader()

    enum SDVXImportPath: Hashable {
        case web
    }

    var body: some View {
        NavigationStack(path: $importPath) {
            List {
                ForEach(importGroups) { group in
                    HStack(alignment: .center, spacing: 6.0) {
                        Text(group.date, style: .date)
                            .foregroundStyle(.primary)
                        Spacer()
                        if let version = group.version {
                            Text(version.marketingName)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .onDelete(perform: { indexSet in
                    deleteImport(indexSet)
                })
            }
            .listStyle(.plain)
            .navigationTitle("ViewTitle.Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .close) { dismiss() }
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .tint(.primary)
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Section {
                            Button("Calendar.Import.LoadSamples.Button") {
                                importSampleCSV()
                            }
                        } header: {
                            Text("Calendar.Import.LoadSamples.Description")
                        }
                    } label: {
                        Image(systemName: "questionmark.circle")
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
                    Task { await reloadImportGroups() }
                }
            }
            .task {
                await reloadImportGroups()
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
        VStack(spacing: 16.0) {
            HStack(spacing: 8.0) {
                DatePicker("Calendar.Import.SelectDate",
                           selection: $importToDate,
                           in: ...Date.now,
                           displayedComponents: .date)
                .datePickerStyle(.compact)
            }
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
        .padding(12.0)
    }

    func reloadImportGroups() async {
        importGroups = await fetcher.allImportGroups()
    }

    func deleteImport(_ indexSet: IndexSet) {
        let groupsToDelete = indexSet.map { importGroups[$0] }
        Task {
            for group in groupsToDelete {
                await importer.deleteImportGroup(id: group.id)
            }
            await reloadImportGroups()
            await MainActor.run {
                NotificationCenter.default.post(name: .dataImported, object: nil)
            }
        }
    }

    func importSampleCSV() {
        progressAlertManager.show(
            title: "Alert.Importing.Title",
            message: "Alert.Importing.Text"
        ) {
            Task { await performSampleImport() }
        }
    }

    private func performSampleImport() async {
        for await progress in await importer.importSampleCSV(to: importToDate, version: sdvxVersion) {
            if let current = progress.currentFileProgress,
               let total = progress.currentFileTotal, total > 0 {
                let percentage = (current * 100) / total
                await MainActor.run { progressAlertManager.updateProgress(percentage) }
            }
        }
        await MainActor.run {
            didImportSucceed = true
            progressAlertManager.hide()
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
