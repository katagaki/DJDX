//
//  ImportView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/23.
//

import Komponents
import SwiftData
import SwiftUI

struct ImportView: View {

    @Environment(\.openURL) var openURL
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.verticalSizeClass) var verticalSizeClass: UserInterfaceSizeClass?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass: UserInterfaceSizeClass?

    @Environment(ProgressAlertManager.self) var progressAlertManager
    @EnvironmentObject var navigationManager: NavigationManager

    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var importPlayType: IIDXPlayType
    @AppStorage(wrappedValue: IIDXVersion.pinkyCrush, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    @Query(sort: \ImportGroup.importDate, order: .reverse) var importGroups: [ImportGroup]

    @State var importToDate: Date = .now
    @State var isAutoImportFailed: Bool = false
    @State var didImportSucceed: Bool = false
    @State var autoImportFailedReason: ImportFailedReason?

    @State var isSelectingCSVFile: Bool = false

    var body: some View {
        NavigationStack(path: $navigationManager[.calendar]) {
            List {
                ForEach(importGroups) { importGroup in
                    VStack(alignment: .leading, spacing: 2.0) {
                        Text(importGroup.importDate, style: .date)
                        HStack(alignment: .center, spacing: 6.0) {
                            if let version = importGroup.iidxVersion {
                                Text(version.marketingName)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(colorScheme == .dark ?
                                                     Color(uiColor: version.darkModeColor) :
                                                        Color(uiColor: version.lightModeColor))
                            }
                            Divider()
                                .frame(maxHeight: 14.0)
                            Text("Shared.SongCount.\(countOfIIDXSongRecords(in: importGroup))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: { indexSet in
                    deleteImport(indexSet)
                })
            }
            .listStyle(.plain)
            .navigationTitle("ViewTitle.Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Spacer()
                }
                ToolbarItem(placement: .topBarLeading) {
                    LargeInlineTitle("ViewTitle.Calendar")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
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
            }
            .safeAreaInset(edge: .bottom, spacing: 0.0) {
                TabBarAccessory(placement: .bottom) {
                    VStack(spacing: 8.0) {
                        DatePicker("Calendar.Import.SelectDate",
                                   selection: $importToDate.animation(.snappy.speed(2.0)),
                                   in: ...Date.now,
                                   displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding([.leading, .trailing], 16.0)
                        .padding([.top], 12.0)
                        ScrollView(.horizontal) {
                            HStack(spacing: 8.0) {
                                PlayTypePicker(playTypeToShow: $importPlayType)
                                switch importPlayType {
                                case .single:
                                    ToolbarButton("Calendar.Import.FromWeb", icon: "globe") {
                                        navigationManager.push(ViewPath.importerWebIIDXSingle, for: .calendar)
                                    }
                                    .popoverTip(StartHereTip(), arrowEdge: .bottom)
                                case .double:
                                    ToolbarButton("Calendar.Import.FromWeb", icon: "globe") {
                                        navigationManager.push(ViewPath.importerWebIIDXDouble, for: .calendar)
                                    }
                                }
                                Menu {
                                    Section {
                                        Button("Importer.CSV.Download.Button", systemImage: "safari") {
                                            openURL(URL(
                                                string: "https://p.eagate.573.jp/game/2dx/\(iidxVersion.rawValue)/djdata/score_download.html"
                                            )!)
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
                                } label: {
                                    ToolbarButton("Calendar.Import.FromCSV", icon: "doc.badge.plus") {
                                        // Intentionally left blank
                                    }
                                }
                            }
                            .padding([.leading, .trailing], 16.0)
                            .padding([.top, .bottom], 12.0)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .alert(
                "Alert.Import.Success.Title",
                isPresented: $didImportSucceed,
                actions: {
                    Button("Shared.OK", role: .cancel) {
                        didImportSucceed = false
                        navigationManager.popToRoot(for: .calendar)
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
                        navigationManager.popToRoot(for: .calendar)
                    }
                },
                message: {
                    Text(errorMessage(for: autoImportFailedReason ?? .serverError))
                }
            )
            .task {
                importToDate = .now
            }
            .sheet(isPresented: $isSelectingCSVFile) {
                DocumentPicker(allowedUTIs: [.commaSeparatedText], onDocumentPicked: { urls in
                    importCSVs(from: urls)
                })
                .ignoresSafeArea(edges: [.bottom])
            }
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .importerWebIIDXSingle:
                    WebImporter(importToDate: $importToDate,
                                importMode: .single,
                                isAutoImportFailed: $isAutoImportFailed,
                                didImportSucceed: $didImportSucceed,
                                autoImportFailedReason: $autoImportFailedReason)
                case .importerWebIIDXDouble:
                    WebImporter(importToDate: $importToDate,
                                importMode: .double,
                                isAutoImportFailed: $isAutoImportFailed,
                                didImportSucceed: $didImportSucceed,
                                autoImportFailedReason: $autoImportFailedReason)
                default: Color.clear
                }
            }
        }
    }

    func countOfIIDXSongRecords(in importGroup: ImportGroup) -> Int {
        let importGroupID = importGroup.id
        let fetchDescriptor = FetchDescriptor<IIDXSongRecord>(
            predicate: #Predicate<IIDXSongRecord> {
                $0.importGroup?.id == importGroupID
            }
        )
        return (try? modelContext.fetchCount(fetchDescriptor)) ?? 0
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
        importGroupsToDelete.forEach { importGroup in
            modelContext.delete(importGroup)
        }
    }

    func importSampleCSV() {
        progressAlertManager.show(
            title: "Alert.Importing.Title",
            message: "Alert.Importing.Text"
        ) {
            Task.detached {
                let actor = DataImporter(modelContainer: sharedModelContainer)
                await actor.importSampleCSV(
                    to: importToDate,
                    for: .single
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
    }

    func importCSVs(from urls: [URL]) {
        progressAlertManager.show(
            title: "Alert.Importing.Title",
            message: "Alert.Importing.Text"
        ) {
            Task.detached(priority: .high) {
                var processedCount = 0
                let totalCount = urls.count
                for url in urls {
                    processedCount += 1
                    await MainActor.run {
                        progressAlertManager.updateTitle("Alert.Importing.Title.\(processedCount).\(totalCount)")
                    }
                    let isAccessSuccessful = url.startAccessingSecurityScopedResource()
                    if isAccessSuccessful {
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
                        url.stopAccessingSecurityScopedResource()
                    } else {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                await MainActor.run {
                    didImportSucceed = true
                    progressAlertManager.hide()
                    try? modelContext.save()
                }
            }
        }
    }
}
