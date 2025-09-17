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
    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    @Query(sort: \ImportGroup.importDate, order: .reverse) var importGroups: [ImportGroup]

    @State var importToDate: Date = .now
    @State var isAutoImportFailed: Bool = false
    @State var didImportSucceed: Bool = false
    @State var autoImportFailedReason: ImportFailedReason?

    @State var isSelectingCSVFile: Bool = false

    let actor = DataImporter(modelContainer: sharedModelContainer)

    var body: some View {
        NavigationStack(path: $navigationManager[.imports]) {
            List {
                ForEach(importGroups) { importGroup in
                    HStack(alignment: .center, spacing: 6.0) {
                        Text(importGroup.importDate, style: .date)
                        Spacer()
                        if let version = importGroup.iidxVersion {
                            Text(version.marketingName)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(colorScheme == .dark ?
                                                 Color(uiColor: version.darkModeColor) :
                                                    Color(uiColor: version.lightModeColor))
                        }
//                            Divider()
//                                .frame(maxHeight: 14.0)
                            // TODO: Refactor or cache this data
//                            Text("Shared.SongCount.\(countOfIIDXSongRecords(in: importGroup))")
//                                .font(.caption)
//                                .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: { indexSet in
                    deleteImport(indexSet)
                })
            }
            .navigator("ViewTitle.Calendar")
            .toolbarBackground(.hidden, for: .tabBar)
            .toolbar {
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
                                   selection: $importToDate,
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
                                        navigationManager.push(ViewPath.importerWebIIDXSingle, for: .imports)
                                    }
                                    .popoverTip(StartHereTip(), arrowEdge: .bottom)
                                case .double:
                                    ToolbarButton("Calendar.Import.FromWeb", icon: "globe") {
                                        navigationManager.push(ViewPath.importerWebIIDXDouble, for: .imports)
                                    }
                                }
                                Menu {
                                    Section {
                                        Button("Importer.CSV.Download.Button", systemImage: "safari") {
                                            openCSVDownloadPage()
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
                        navigationManager.popToRoot(for: .imports)
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
                        navigationManager.popToRoot(for: .imports)
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
}
