import Komponents
import SwiftUI

struct DDRImportView: View {

    @Environment(\.dismiss) var dismiss

    @State var importProgress = ProgressReporter()

    @AppStorage(wrappedValue: DDRVersion.world, "Global.DDR.Version") var ddrVersion: DDRVersion

    @State var importPath = NavigationPath()
    @State var importToDate: Date = .now
    @State var isAutoImportFailed: Bool = false
    @State var didImportSucceed: Bool = false
    @State var autoImportFailedReason: ImportFailedReason?
    @State var importGroups: [DDRImportGroupInfo] = []

    let importer = DDRImporter()
    let fetcher = DDRReader()

    enum DDRImportPath: Hashable {
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
                                .foregroundStyle(version.color)
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
            .navigationDestination(for: DDRImportPath.self) { path in
                switch path {
                case .web:
                    DDRWebImporter(importToDate: $importToDate,
                                   isAutoImportFailed: $isAutoImportFailed,
                                   didImportSucceed: $didImportSucceed,
                                   autoImportFailedReason: $autoImportFailedReason)
                }
            }
        }
        .environment(importProgress)
        .progressOverlay(importProgress)
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
            Button {
                importPath.append(DDRImportPath.web)
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
