import SwiftUI

struct MoreICloudBackup: View {

    @Environment(\.dismiss) var dismiss

    @AppStorage(wrappedValue: false, ICloudBackupManager.enabledKey) var isBackupEnabled: Bool
    @AppStorage(wrappedValue: 0.0, ICloudBackupManager.lastBackupDateKey) var lastBackupDate: Double
    @AppStorage(wrappedValue: false, ICloudBackupManager.restorePromptCompletedKey)
    var hasCompletedRestorePrompt: Bool

    @State var isBackingUp: Bool = false
    @State var isBackupFailed: Bool = false

    var body: some View {
        List {
            Section {
                Toggle("ICloudBackup.Enable", systemImage: "icloud", isOn: $isBackupEnabled)
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
        }
        .navigationTitle("ICloudBackup.Title")
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
            } else {
                ICloudBackupManager.cancelScheduledBackup()
            }
        }
        .alert("Alert.ICloudBackup.Failed.Title", isPresented: $isBackupFailed) {
            Button("Shared.OK", role: .cancel) {
                isBackupFailed = false
            }
        } message: {
            Text("Alert.ICloudBackup.Failed.Subtitle")
        }
    }

    func backUpNow() {
        isBackingUp = true
        Task {
            let isSuccessful = await ICloudBackupManager.performBackup()
            isBackingUp = false
            if !isSuccessful {
                isBackupFailed = true
            }
        }
    }
}
