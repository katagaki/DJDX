import AVFoundation
import PhotosUI
import SwiftUI

private struct CropPreviewItem: Identifiable {
    let id = UUID()
    let data: Data
}

struct ActiveSessionView: View {
    var store: SessionStore

    @State private var isPresentingCamera: Bool = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isShowingCameraDeniedAlert: Bool = false
    @State private var cropQueue: [Data] = []
    @State private var currentCropItem: CropPreviewItem? = nil
    @ObservedObject private var workoutBridge = SessionWorkoutBridge.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0.0) {
                header
                Divider()
                playList
                    .safeAreaInset(edge: .bottom) {
                        captureBar
                    }
            }
            .background {
                LinearGradient(
                    colors: [.backgroundGradientTop, .backgroundGradientBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .navigationTitle("Sessions.Active.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .close) {
                            store.endSession()
                        }
                        .accessibilityLabel("Sessions.End")
                    } else {
                        Button("Sessions.End", role: .destructive) {
                            store.endSession()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled()
        .fullScreenCover(isPresented: $isPresentingCamera) {
            SessionCameraView { data in
                store.capture(data, source: .camera)
                isPresentingCamera = false
            } onCancel: {
                isPresentingCamera = false
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            importPicked(items)
        }
        .onReceive(NotificationCenter.default.publisher(for: .capturedPlayDidChange)
            .receive(on: RunLoop.main)) { _ in
            store.refreshPlays()
        }
        .fullScreenCover(item: $currentCropItem) { item in
            SessionCropPreviewView(imageData: item.data) { processedData in
                store.capture(processedData, source: .picker)
                currentCropItem = nil
                showNextCrop()
            } onRetake: {
                currentCropItem = nil
                showNextCrop()
            }
        }
        .alert("Sessions.Camera.Denied.Title", isPresented: $isShowingCameraDeniedAlert) {
            Button("Shared.OK", role: .cancel) {}
        } message: {
            Text("Sessions.Camera.Denied.Message")
        }
    }

    private var numberFont: Font {
        .system(.largeTitle, design: .rounded)
        .weight(.bold)
        .monospacedDigit()
    }

    @ViewBuilder
    private var header: some View {
        if let session = store.activeSession {
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0.0) {
                        Text("Sessions.Elapsed")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text(verbatim: elapsedString(since: session.startDate, now: context.date))
                            .font(numberFont)
                    }
                    Spacer()
                    if workoutBridge.isWorkoutActive {
                        VStack(alignment: .center, spacing: 0.0) {
                            Text("Sessions.HeartRate")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6.0) {
                                Image(systemName: "heart.fill")
                                    .font(.title3)
                                Text(verbatim: workoutBridge.heartRate > 0 ? "\(workoutBridge.heartRate)" : "--")
                                    .font(numberFont)
                            }
                            .foregroundStyle(.red)
                            if workoutBridge.activeCalories > 0 {
                                Text(verbatim: "\(workoutBridge.activeCalories) kcal")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    VStack(alignment: .trailing, spacing: 0.0) {
                        Text("Sessions.Plays")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text(verbatim: "\(store.plays.count)")
                            .font(numberFont)
                    }
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private var playList: some View {
        if store.plays.isEmpty {
            ContentUnavailableView(
                "Sessions.Empty.Title",
                systemImage: "camera.viewfinder",
                description: Text("Sessions.Empty.Message")
            )
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0.0) {
                    ForEach(store.plays.reversed()) { play in
                        NavigationLink {
                            CapturedPlayDetailView(store: store, play: play)
                        } label: {
                            CapturedPlayRow(play: play)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                                store.deletePlay(play)
                            }
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private var captureBar: some View {
        HStack(spacing: 12.0) {
            captureButton
            importButton
        }
        .padding()
    }

    @ViewBuilder
    private var captureButton: some View {
        let button = Button {
            requestCameraThenPresent()
        } label: {
            Label("Sessions.Capture", systemImage: "camera.fill")
                .frame(maxWidth: .infinity)
        }
        if #available(iOS 26.0, *) {
            button.buttonStyle(.glassProminent).controlSize(.large)
        } else {
            button.buttonStyle(.borderedProminent).controlSize(.large)
        }
    }

    @ViewBuilder
    private var importButton: some View {
        let picker = PhotosPicker(selection: $pickerItems, maxSelectionCount: 0, matching: .images) {
            Label("Sessions.Import", systemImage: "photo.on.rectangle")
                .frame(maxWidth: .infinity)
        }
        if #available(iOS 26.0, *) {
            picker.buttonStyle(.glass).controlSize(.large)
        } else {
            picker.buttonStyle(.bordered).controlSize(.large)
        }
    }

    private func requestCameraThenPresent() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isPresentingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { isPresentingCamera = true } else { isShowingCameraDeniedAlert = true }
                }
            }
        default:
            isShowingCameraDeniedAlert = true
        }
    }

    private func importPicked(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        cropQueue.append(data)
                        if currentCropItem == nil { showNextCrop() }
                    }
                }
            }
            await MainActor.run { pickerItems = [] }
        }
    }

    private func showNextCrop() {
        guard !cropQueue.isEmpty else { return }
        currentCropItem = CropPreviewItem(data: cropQueue.removeFirst())
    }

    private func elapsedString(since start: Date, now: Date) -> String {
        let interval = Int(max(0, now.timeIntervalSince(start)))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
