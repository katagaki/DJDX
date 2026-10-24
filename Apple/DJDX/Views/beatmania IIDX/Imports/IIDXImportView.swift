import Komponents
import SwiftUI

// swiftlint:disable:next type_body_length
struct IIDXImportView: View {

    @Environment(\.openURL) var openURL
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.verticalSizeClass) var verticalSizeClass: UserInterfaceSizeClass?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass: UserInterfaceSizeClass?

    @Environment(\.dismiss) var dismiss

    @State var importProgress = ProgressReporter()

    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var importPlayType: IIDXPlayType
    @AppStorage(wrappedValue: IIDXVersion.zinrai, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    @State var importPath = NavigationPath()
    @State var importGroups: [ImportGroup] = []

    @State var importToDate: Date = .now
    @State var isAutoImportFailed: Bool = false
    @State var didImportSucceed: Bool = false
    @State var autoImportFailedReason: ImportFailedReason?

    @State var isSelectingCSVFile: Bool = false

    let actor = IIDXImporter()
    let fetcher = IIDXReader()

    var body: some View {
        NavigationStack(path: $importPath) {
            List {
                ForEach(importGroups) { importGroup in
                    HStack(alignment: .center, spacing: 6.0) {
                        Text(importGroup.importDate, style: .date)
                            .foregroundStyle(.primary)
                        Spacer()
                        if let version = importGroup.iidxVersion {
                            Text(version.marketingName)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(colorScheme == .dark ?
                                                 Color(uiColor: version.darkModeColor) :
                                                    Color(uiColor: version.lightModeColor))
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
                        Button(role: .close) {
                            dismiss()
                        }
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
                if #available(iOS 26.0, *) {
                    bottomBar()
                        .padding(.top, 2.0)
                        .contentShape(.rect)
                        .clipShape(.rect(cornerRadius: 24.0))
                        .glassEffect(.regular, in: .rect(cornerRadius: 24.0))
                        .padding()
                } else {
                    TabBarAccessory(placement: .bottom) {
                        bottomBar()
                            .contentShape(.rect)
                    }
                }
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
                message: {
                    Text("Alert.Import.Success.Subtitle")
                }
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
                message: {
                    Text(errorMessage(for: autoImportFailedReason ?? .serverError))
                }
            )
            .task {
                importToDate = .now
                await reloadImportGroups()
            }
            .onChange(of: didImportSucceed) { _, newValue in
                if newValue {
                    NotificationCenter.default.post(name: .dataImported, object: nil)
                    Task { await reloadImportGroups() }
                }
            }
            .sheet(isPresented: $isSelectingCSVFile) {
                DocumentPicker(allowedUTIs: [.commaSeparatedText], onDocumentPicked: { urls in
                    importCSVs(from: urls)
                })
                .ignoresSafeArea(edges: [.bottom])
            }
            .navigationDestination(for: ImportPath.self) { viewPath in
                switch viewPath {
                case .importerWebIIDXSingle:
                    IIDXWebImporter(importToDate: $importToDate,
                                importMode: .single,
                                isAutoImportFailed: $isAutoImportFailed,
                                didImportSucceed: $didImportSucceed,
                                autoImportFailedReason: $autoImportFailedReason)
                case .importerWebIIDXDouble:
                    IIDXWebImporter(importToDate: $importToDate,
                                importMode: .double,
                                isAutoImportFailed: $isAutoImportFailed,
                                didImportSucceed: $didImportSucceed,
                                autoImportFailedReason: $autoImportFailedReason)
                default: Color.clear
                }
            }
        }
        .environment(importProgress)
        .progressOverlay(importProgress)
    }

    // swiftlint:disable function_body_length
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
                    switch importPlayType {
                    case .single: importPath.append(ImportPath.importerWebIIDXSingle)
                    case .double: importPath.append(ImportPath.importerWebIIDXDouble)
                    }
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
                .popoverTip(StartHereTip(), arrowEdge: .bottom)
                Menu {
                    Section {
                        Button(.importerCsvDownloadButton, systemImage: "safari") {
                            openCSVDownloadPage()
                        }
                    } header: {
                        Text("Importer.CSV.Download.Description")
                            .foregroundColor(.primary)
                            .textCase(nil)
                            .font(.body)
                    }
                    Section {
                        Button(.importerCsvLoadButton, systemImage: "folder") {
                            isSelectingCSVFile = true
                        }
                    } header: {
                        Text("Importer.CSV.Load.Description")
                            .foregroundColor(.primary)
                            .textCase(nil)
                            .font(.body)
                    }
                    Section {
                        Button("Importer.CSV.Backup.Button", systemImage: "folder.badge.gearshape") {
                            let documentsUrl = FileManager.default.urls(for: .documentDirectory,
                                                                        in: .userDomainMask).first!
#if targetEnvironment(macCatalyst)
                            UIApplication.shared.open(documentsUrl)
#else
                            if let sharedUrl = URL(string: "shareddocuments://\(documentsUrl.path)"),
                               UIApplication.shared.canOpenURL(sharedUrl) {
                                UIApplication.shared.open(sharedUrl)
                            }
#endif
                        }
                    } header: {
                        Text("Importer.CSV.Backup.Description")
                            .foregroundColor(.primary)
                            .textCase(nil)
                            .font(.body)
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
                .menuOrder(.fixed)
            }
        }
        .padding(12.0)
    }
    // swiftlint:enable function_body_length

    func reloadImportGroups() async {
        importGroups = await fetcher.allImportGroupsSortedByDateDescending()
    }

    func errorMessage(for reason: ImportFailedReason) -> String {
        switch reason {
        case .noPremiumCourse:
            return NSLocalizedString("Alert.Import.Error.Subtitle.NoPremiumCourse", comment: "")
        case .noEAmusementPass:
            return NSLocalizedString("Alert.Import.Error.Subtitle.NoEAmusementPass", comment: "")
        case .noPlayData:
            return NSLocalizedString("Alert.Import.Error.Subtitle.NoPlayData", comment: "")
        case .serverError:
            return NSLocalizedString("Alert.Import.Error.Subtitle.ServerError", comment: "")
        case .maintenance:
            return NSLocalizedString("Alert.Import.Error.Subtitle.Maintenance", comment: "")
        }
    }

    func deleteImport(_ indexSet: IndexSet) {
        var importGroupsToDelete: [ImportGroup] = []
        indexSet.forEach { index in
            importGroupsToDelete.append(importGroups[index])
        }
        Task {
            for importGroup in importGroupsToDelete {
                await actor.deleteImportGroup(id: importGroup.id)
            }
            await reloadImportGroups()
            await MainActor.run {
                NotificationCenter.default.post(name: .dataImported, object: nil)
            }
        }
    }

    func openCSVDownloadPage() {
        openURL(URL(
            string: "https://p.eagate.573.jp/game/2dx/\(iidxVersion.rawValue)/djdata/score_download.html"
        )!)
    }

    func importSampleCSV() {
        importProgress.show(
            title: "Alert.Importing.Title",
            message: "Alert.Importing.Text"
        )
        Task { await performSampleCSVImport() }
    }

    private func performSampleCSVImport() async {
        for await progress in await actor.importSampleCSV(
            to: importToDate,
            for: .single
        ) {
            if let currentFileProgress = progress.currentFileProgress,
                let currentFileTotal = progress.currentFileTotal {
                let progress = (currentFileProgress * 100) / currentFileTotal
                await MainActor.run {
                    importProgress.updateProgress(progress)
                }
            }
        }
        await MainActor.run {
            didImportSucceed = true
            importProgress.hide()
        }
    }

    func importCSVs(from urls: [URL]) {
        importProgress.show(
            title: "Alert.Importing.Title",
            message: "Alert.Importing.Text"
        )
        Task { await performCSVImport(from: urls) }
    }

    private func performCSVImport(from urls: [URL]) async {
        for await progress in await actor.importCSVs(
            urls: urls,
            to: importToDate,
            for: importPlayType,
            from: iidxVersion
        ) {
            if let filesProcessed = progress.filesProcessed,
               let fileCount = progress.fileCount {
                await MainActor.run {
                    importProgress.updateTitle("Alert.Importing.Title.\(filesProcessed).\(fileCount)")
                }
            }
            if let currentFileProgress = progress.currentFileProgress,
                let currentFileTotal = progress.currentFileTotal,
               currentFileTotal > 0 {
                let progress = (currentFileProgress * 100) / currentFileTotal
                await MainActor.run {
                    importProgress.updateProgress(progress)
                }
            }
        }
        await MainActor.run {
            didImportSucceed = true
            importProgress.hide()
        }
    }
}
