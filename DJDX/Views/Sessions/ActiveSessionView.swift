import AVFoundation
import PhotosUI
import SwiftUI

struct ActiveSessionView: View {
    var store: SessionStore

    @State private var isPresentingCamera: Bool = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isShowingCameraDeniedAlert: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0.0) {
                header
                Divider()
                playList
                captureBar
            }
            .navigationTitle("Sessions.Active.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sessions.End", role: .destructive) {
                        store.endSession()
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
            .ignoresSafeArea()
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            importPicked(items)
        }
        .onReceive(NotificationCenter.default.publisher(for: .capturedPlayDidChange)
            .receive(on: RunLoop.main)) { _ in
            store.refreshPlays()
        }
        .alert("Sessions.Camera.Denied.Title", isPresented: $isShowingCameraDeniedAlert) {
            Button("Shared.OK", role: .cancel) {}
        } message: {
            Text("Sessions.Camera.Denied.Message")
        }
    }

    @ViewBuilder
    private var header: some View {
        if let session = store.activeSession {
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                HStack {
                    VStack(alignment: .leading, spacing: 2.0) {
                        Text("Sessions.Elapsed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(verbatim: elapsedString(since: session.startDate, now: context.date))
                            .font(.title2.monospacedDigit().weight(.semibold))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2.0) {
                        Text("Sessions.Plays")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(verbatim: "\(store.plays.count)")
                            .font(.title2.monospacedDigit().weight(.semibold))
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
            List {
                ForEach(store.plays.reversed()) { play in
                    NavigationLink {
                        CapturedPlayDetailView(store: store, play: play)
                    } label: {
                        CapturedPlayRow(play: play)
                    }
                }
                .onDelete { offsets in
                    let reversed = Array(store.plays.reversed())
                    for offset in offsets { store.deletePlay(reversed[offset]) }
                }
            }
            .listStyle(.plain)
        }
    }

    private var captureBar: some View {
        HStack(spacing: 12.0) {
            Button {
                requestCameraThenPresent()
            } label: {
                Label("Sessions.Capture", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            PhotosPicker(selection: $pickerItems, maxSelectionCount: 0, matching: .images) {
                Label("Sessions.Import", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
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
                    await MainActor.run { store.capture(data, source: .picker) }
                }
            }
            await MainActor.run { pickerItems = [] }
        }
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
