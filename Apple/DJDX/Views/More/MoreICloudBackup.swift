import SwiftUI
import UniformTypeIdentifiers

struct MoreICloudBackup: View {

    @Environment(\.dismiss) var dismiss

    @AppStorage(wrappedValue: false, ICloudBackupManager.enabledKey) var isBackupEnabled: Bool
    @AppStorage(wrappedValue: 0.0, ICloudBackupManager.lastBackupDateKey) var lastBackupDate: Double
    @AppStorage(wrappedValue: false, ICloudBackupManager.restorePromptCompletedKey)
    var hasCompletedRestorePrompt: Bool

    @State var isBackingUp: Bool = false
    @State var isBackupFailed: Bool = false
    @State var backupFailureDetail: String = ""
    @State var isPreparingExport: Bool = false
    @State var isExportFailed: Bool = false
    @State var exportedArchive: ExportedArchive?

    var body: some View {
        List {
            Section {
                Toggle("ICloudBackup.Enable", systemImage: "icloud", isOn: $isBackupEnabled)
            } header: {
                Text("More.ManageData.ICloudBackup")
            } footer: {
                Text("ICloudBackup.Description")
            }
            if isBackupEnabled {
                Section {
                    LabeledContent("ICloudBackup.LastBackup") {
                        if lastBackupDate > 0.0 {
                            Text(Date(timeIntervalSince1970: lastBackupDate), format: .dateTime)
                        } else {
                            Text("ICloudBackup.LastBackup.Never")
                        }
                    }
                    Button {
                        backUpNow()
                    } label: {
                        HStack {
                            Text("ICloudBackup.BackUpNow")
                            if isBackingUp {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isBackingUp)
                }
            }
            Section {
                Button {
                    exportNow()
                } label: {
                    HStack {
                        Label("Backup.Export", systemImage: "square.and.arrow.up")
                        if isPreparingExport {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isPreparingExport)
            } footer: {
                Text("Backup.Export.Footer")
            }
        }
        .navigationTitle("Backup.Title")
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
        }
        .animation(.smooth.speed(2.0), value: isBackupEnabled)
        .onChange(of: isBackupEnabled) { _, newValue in
            if newValue {
                hasCompletedRestorePrompt = true
                ICloudBackupManager.scheduleNextBackup()
                backUpNow()
            } else {
                ICloudBackupManager.cancelScheduledBackup()
            }
        }
        .sheet(item: $exportedArchive) { archive in
            ExportShareSheet(url: archive.url)
        }
        .alert("Alert.Backup.ExportFailed.Title", isPresented: $isExportFailed) {
            Button("Shared.OK", role: .cancel) {
                isExportFailed = false
            }
        } message: {
            Text("Alert.Backup.ExportFailed.Subtitle")
        }
        .alert("Alert.ICloudBackup.Failed.Title", isPresented: $isBackupFailed) {
            Button("Shared.OK", role: .cancel) {
                isBackupFailed = false
            }
        } message: {
            Text("Alert.ICloudBackup.Failed.Subtitle")
            + Text(verbatim: "\n\n")
            + Text(verbatim: backupFailureDetail)
        }
    }

    func backUpNow() {
        isBackingUp = true
        UIApplication.shared.isIdleTimerDisabled = true
        Task {
            let failureDetail = await ICloudBackupManager.performBackup()
            isBackingUp = false
            UIApplication.shared.isIdleTimerDisabled = isPreparingExport
            if let failureDetail {
                backupFailureDetail = failureDetail
                isBackupFailed = true
            }
        }
    }

    func exportNow() {
        isPreparingExport = true
        UIApplication.shared.isIdleTimerDisabled = true
        Task {
            let archiveURL = await ICloudBackupManager.exportArchive()
            isPreparingExport = false
            UIApplication.shared.isIdleTimerDisabled = isBackingUp
            if let archiveURL {
                exportedArchive = ExportedArchive(url: archiveURL)
            } else {
                isExportFailed = true
            }
        }
    }
}

struct ExportedArchive: Identifiable {
    let url: URL
    var id: String { url.path }
}

struct ExportShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
