@preconcurrency import AVFoundation
import SwiftUI

struct ChartReceiverView: View {

    @Environment(\.dismiss) private var dismiss

    let onReceive: ([UInt8]) -> Void
    @State private var state = ChartReceiveState()
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var judgementFlash = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if cameraStatus == .authorized {
                ChartCameraView { newState in
                    if newState.receivedBlocks.count > state.receivedBlocks.count {
                        judgementFlash += 1
                    }
                    state = newState
                    if let message = newState.message {
                        onReceive(message)
                        dismiss()
                    }
                }
                .ignoresSafeArea()
                cornerOverlay
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            } else if cameraStatus == .denied || cameraStatus == .restricted {
                ContentUnavailableView("Lamp.Receive.CameraDenied", systemImage: "camera.fill")
                    .foregroundStyle(.white)
            }
        }
        .overlay(alignment: .top) {
            statusBar
        }
        .overlay(alignment: .center) {
            if judgementFlash > 0 {
                Text(verbatim: "PGREAT")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .italic()
                    .foregroundStyle(LinearGradient(colors: [.white, .yellow, .orange], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .orange.opacity(0.8), radius: 12)
                    .id(judgementFlash)
                    .transition(.asymmetric(insertion: .scale(scale: 1.4).combined(with: .opacity), removal: .opacity))
                    .phaseAnimator([1.0, 0.0]) { view, phase in
                        view.opacity(phase)
                    } animation: { phase in
                        phase == 0 ? .easeOut(duration: 0.6).delay(0.3) : .easeOut(duration: 0.1)
                    }
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(role: .close) {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .padding()
        }
        .statusBarHidden()
        .task {
            if cameraStatus == .notDetermined {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                cameraStatus = granted ? .authorized : .denied
            }
        }
    }

    private var statusBar: some View {
        VStack(spacing: 8) {
            Group {
                if state.corners != nil {
                    Label("Lamp.Receive.Reading", systemImage: "viewfinder")
                        .foregroundStyle(.yellow)
                } else {
                    Label(state.hasLocked ? "Lamp.Receive.Reacquiring" : "Lamp.Receive.Searching", systemImage: "viewfinder")
                }
            }
            .font(.subheadline.weight(.semibold))
            if let count = state.blockCount {
                HStack(spacing: 6) {
                    ForEach(0..<count, id: \.self) { index in
                        Capsule()
                            .fill(state.receivedBlocks.contains(index) ? Color.yellow : Color.white.opacity(0.3))
                            .frame(width: 22, height: 6)
                    }
                }
                Text("Lamp.Receive.Blocks.\(state.receivedBlocks.count).\(count)")
                    .font(.caption.monospacedDigit())
            } else {
                Text("Lamp.Receive.Hint")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .padding(.top, 8)
        .padding(.horizontal, 72)
    }

    private var cornerOverlay: some View {
        Canvas { context, size in
            guard let corners = state.corners, state.frameSize.width > 0 else { return }
            let scale = max(size.width / state.frameSize.width, size.height / state.frameSize.height)
            let dx = (size.width - state.frameSize.width * scale) / 2
            let dy = (size.height - state.frameSize.height * scale) / 2
            let points = corners.map { CGPoint(x: $0.x * scale + dx, y: $0.y * scale + dy) }
            var path = Path()
            path.addLines(points + [points[0]])
            context.stroke(path, with: .color(.yellow), lineWidth: 2)
            for point in points {
                context.stroke(Path(ellipseIn: CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20)),
                               with: .color(.yellow), lineWidth: 2)
            }
        }
    }
}

struct ChartCameraView: UIViewControllerRepresentable {
    let onUpdate: (ChartReceiveState) -> Void

    func makeUIViewController(context: Context) -> ChartCameraViewController {
        let controller = ChartCameraViewController()
        controller.onUpdate = onUpdate
        return controller
    }

    func updateUIViewController(_ controller: ChartCameraViewController, context: Context) {
        controller.onUpdate = onUpdate
    }
}

final class ChartCameraViewController: UIViewController {

    var onUpdate: ((ChartReceiveState) -> Void)?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let sessionQueue = DispatchQueue(label: "com.tsubuzaki.DJDX.ChartCamera")
    private let videoQueue = DispatchQueue(label: "com.tsubuzaki.DJDX.ChartCamera.Video")
    private lazy var processor = ChartFrameProcessor { [weak self] state in
        DispatchQueue.main.async {
            self?.onUpdate?(state)
            if state.message != nil { self?.stop() }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        let session = session, output = output, processor = processor, videoQueue = videoQueue
        sessionQueue.async {
            Self.configure(session: session, output: output, processor: processor, queue: videoQueue)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stop()
    }

    private func stop() {
        let session = session
        sessionQueue.async {
            if session.isRunning { session.stopRunning() }
        }
    }

    nonisolated private static func configure(session: AVCaptureSession, output: AVCaptureVideoDataOutput,
                                              processor: ChartFrameProcessor, queue: DispatchQueue) {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input), session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(processor, queue: queue)
        session.addOutput(output)
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        if (try? device.lockForConfiguration()) != nil {
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            device.setExposureTargetBias(-0.7)
            device.unlockForConfiguration()
        }
        session.commitConfiguration()
        session.startRunning()
    }
}

final class ChartFrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    private let decoder = ChartDecoder()
    private let onUpdate: @Sendable (ChartReceiveState) -> Void
    private var finished = false

    init(onUpdate: @escaping @Sendable (ChartReceiveState) -> Void) {
        self.onUpdate = onUpdate
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !finished, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        guard let frame = Self.frame(from: buffer) else { return }
        let state = decoder.process(frame, time: time)
        if state.message != nil { finished = true }
        onUpdate(state)
    }

    static func frame(from buffer: CVPixelBuffer) -> ChartFrame? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer)?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let factor = max(1, min(width, height) / 360)
        let outWidth = width / factor, outHeight = height / factor
        var luma = [Float](repeating: 0, count: outWidth * outHeight)
        var green = [Float](repeating: 0, count: outWidth * outHeight)
        let norm = 1 / (255 * Float(factor * factor))
        for y in 0..<outHeight {
            for x in 0..<outWidth {
                var b = 0, g = 0, r = 0
                for sy in 0..<factor {
                    let row = base + (y * factor + sy) * bytesPerRow + x * factor * 4
                    for sx in 0..<factor {
                        b += Int(row[sx * 4]); g += Int(row[sx * 4 + 1]); r += Int(row[sx * 4 + 2])
                    }
                }
                let fr = Float(r) * norm, fg = Float(g) * norm, fb = Float(b) * norm
                let i = y * outWidth + x
                luma[i] = max(fr, fg, fb)
                green[i] = fg > 0.3 ? fg - max(fr, fb) : 0
            }
        }
        return ChartFrame(width: outWidth, height: outHeight, luma: luma, green: green)
    }
}
