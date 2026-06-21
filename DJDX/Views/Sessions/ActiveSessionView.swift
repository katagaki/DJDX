import AVFoundation
import PhotosUI
import SwiftUI

struct ActiveSessionView: View {
    var store: IIDXSessionStore

    @State private var isPresentingCamera: Bool = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isShowingCameraDeniedAlert: Bool = false
    @State private var photoAlert: PhotoExportAlert?
    @ObservedObject private var workoutBridge = IIDXSessionWorkoutBridge.shared

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
                if !store.plays.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Sessions.Photos.ExportAll", systemImage: "square.and.arrow.up.on.square") {
                            exportAllToPhotos()
                        }
                    }
                }
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
        .onAppear(perform: consumePendingCaptureRequest)
        .onChange(of: store.pendingCaptureRequest) { _, _ in
            consumePendingCaptureRequest()
        }
        .alert("Sessions.Camera.Denied.Title", isPresented: $isShowingCameraDeniedAlert) {
            Button("Shared.OK", role: .cancel) {}
        } message: {
            Text("Sessions.Camera.Denied.Message")
        }
        .alert(item: $photoAlert) { alert in
            switch alert {
            case .saved:
                return Alert(title: Text("Sessions.Photos.Saved"), dismissButton: .default(Text("Shared.OK")))
            case .failed:
                return Alert(title: Text("Sessions.Photos.Failed"), dismissButton: .default(Text("Shared.OK")))
            case .denied:
                return Alert(
                    title: Text("Sessions.Photos.Denied.Title"),
                    message: Text("Sessions.Photos.Denied.Message"),
                    dismissButton: .default(Text("Shared.OK"))
                )
            }
        }
    }

    private func exportAllToPhotos() {
        let filenames = store.plays.map(\.rawImageFilename)
        Task {
            let images: [UIImage] = await Task.detached {
                filenames.compactMap { IIDXSessionImageStore.shared.image(for: $0) }
            }.value
            switch await SessionPhotoExporter.save(images) {
            case .saved: photoAlert = .saved
            case .denied: photoAlert = .denied
            case .failed: photoAlert = .failed
            }
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
                                    .heartbeat(isActive: workoutBridge.heartRate > 0)
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
                    }
                }
            }
            .scrollContentBackground(.hidden)
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
        let picker = PhotosPicker(selection: $pickerItems, maxSelectionCount: 1, matching: .images) {
            Label("Sessions.Import", systemImage: "photo.on.rectangle")
                .frame(maxWidth: .infinity)
        }
        if #available(iOS 26.0, *) {
            picker.buttonStyle(.glass).controlSize(.large)
        } else {
            picker.buttonStyle(.bordered).controlSize(.large)
        }
    }

    private func consumePendingCaptureRequest() {
        guard store.pendingCaptureRequest else { return }
        store.pendingCaptureRequest = false
        requestCameraThenPresent()
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
                        store.capture(data, source: .picker)
                    }
                }
            }
            await MainActor.run { pickerItems = [] }
        }
    }

    private enum PhotoExportAlert: Int, Identifiable {
        case saved, denied, failed
        var id: Int { rawValue }
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
