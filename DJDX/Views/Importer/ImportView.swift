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
                    Button {
                        navigationManager.push(.importDetail(importGroup: importGroup), for: .imports)
                    } label: {
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
                    }
                }
                .onDelete(perform: { indexSet in
                    deleteImport(indexSet)
                })
                .listRowBackground(Color.clear)
            }
            .navigator("ViewTitle.Calendar")
            .toolbarBackground(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if #available(iOS 26.0, *) {
                        Menu(importPlayType.displayName()) {
                            Picker("Shared.PlayType", selection: $importPlayType) {
                                Text(verbatim: "SP")
                                    .tag(IIDXPlayType.single)
                                Text(verbatim: "DP")
                                    .tag(IIDXPlayType.double)
                            }
                            .pickerStyle(.inline)
                        }
                    } else {
                        PlayTypePicker(playTypeToShow: $importPlayType)
                    }
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
                if #available(iOS 26.0, *) {
                    bottomBar()
                        .padding(.vertical, 2.0)
                        .clipShape(.containerRelative)
                        .glassEffect(.regular, in: .containerRelative)
                        .padding()
                } else {
                    TabBarAccessory(placement: .bottom) {
                        bottomBar()
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
                case .importDetail(let importGroup):
                    ImportDetailView(importGroup: importGroup)
                default: Color.clear
                }
            }
        }
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
                    case .single: navigationManager.push(ViewPath.importerWebIIDXSingle, for: .imports)
                    case .double: navigationManager.push(ViewPath.importerWebIIDXDouble, for: .imports)
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
            }
        }
        .padding()
    }
    // swiftlint:enable function_body_length
}
