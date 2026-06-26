import AVFoundation
import SwiftUI
import UIKit

struct SessionCameraView: UIViewControllerRepresentable {
    var onCapture: (Data, [DetectedRegion]) -> Void
    var onCancel: () -> Void
    var onUnavailable: () -> Void = {}

    func makeUIViewController(context: Context) -> SessionCameraViewController {
        let controller = SessionCameraViewController()
        controller.onCapture = onCapture
        controller.onCancel = onCancel
        controller.onUnavailable = onUnavailable
        return controller
    }

    func updateUIViewController(_ uiViewController: SessionCameraViewController, context: Context) {}
}

final class SessionCameraViewController: UIViewController {
    var onCapture: ((Data, [DetectedRegion]) -> Void)?
    var onCancel: (() -> Void)?
    var onUnavailable: (() -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let liveProbe = LiveResultProbe()
    private let sessionQueue = DispatchQueue(label: "com.tsubuzaki.DJDX.SessionCamera")
    private let videoQueue = DispatchQueue(label: "com.tsubuzaki.DJDX.SessionCamera.Video")
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let topGradient = CAGradientLayer()
    private let bottomGradient = CAGradientLayer()
    private let hintLabel = UILabel()
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var captureDelegate: PhotoCaptureDelegate?

    private let overlayView = UIView()
    private let shutterButton = UIButton(type: .custom)
    private let cancelButton = UIButton(type: .system)
    private let optionsButton = UIButton(type: .system)
    private let playerSideControl = UISegmentedControl(items: ["1P", "2P"])
    private let shutterHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private var overlayAngle: CGFloat = .pi / 2

    private let scoreRegionLayer = CAShapeLayer()
    private let titleRegionLayer = CAShapeLayer()
    private let scoreRegionColor = UIColor.systemTeal
    private let titleRegionColor = UIColor.systemYellow
    private let scoreRegion = CGRect(x: 0.03, y: 0.04, width: 0.45, height: 0.94)
    private let titleRegion = CGRect(x: 0.50, y: 0.82, width: 0.29, height: 0.16)
    private let playerSideDefaultsKey = "Sessions.Camera.IsPlayer2"
    private var isPlayer2 = false
    private let guidePerspective: CGFloat = 0.14

    private let stagedOverlay = StagedResultsOverlayView()
    private var stagedTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(previewLayer)
        topGradient.colors = [UIColor.black.withAlphaComponent(0.6).cgColor, UIColor.clear.cgColor]
        bottomGradient.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.6).cgColor]
        view.layer.addSublayer(topGradient)
        view.layer.addSublayer(bottomGradient)
        overlayView.backgroundColor = .clear
        overlayView.isUserInteractionEnabled = false
        view.addSubview(overlayView)
        configureRegionLayer(scoreRegionLayer, color: scoreRegionColor)
        configureRegionLayer(titleRegionLayer, color: titleRegionColor)
        overlayView.layer.addSublayer(scoreRegionLayer)
        overlayView.layer.addSublayer(titleRegionLayer)
        configureControls()
        configureStagedOverlay()
        sessionQueue.async { [weak self] in self?.configureSession() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        shutterHaptic.prepare()
        NotificationCenter.default.addObserver(self, selector: #selector(deviceOrientationDidChange),
                                               name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(powerStateDidChange),
                                               name: .NSProcessInfoPowerStateDidChange, object: nil)
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyLiveDetectionState()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        liveProbe.stop()
        stopStagedTimer()
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .NSProcessInfoPowerStateDidChange, object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    @objc private func deviceOrientationDidChange() {
        applyPreviewRotation()
        applyVideoOutputRotation()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.applyPreviewRotation()
            self?.applyVideoOutputRotation()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = view.bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        let fade: CGFloat = 160
        topGradient.frame = CGRect(x: 0, y: 0, width: bounds.width, height: fade)
        bottomGradient.frame = CGRect(x: 0, y: bounds.height - fade, width: bounds.width, height: fade)
        CATransaction.commit()

        let isPortrait = bounds.height > bounds.width
        overlayAngle = isPortrait ? .pi / 2 : 0
        overlayView.bounds = isPortrait
            ? CGRect(x: 0, y: 0, width: bounds.height, height: bounds.width)
            : bounds
        overlayView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        overlayView.transform = CGAffineTransform(rotationAngle: overlayAngle)

        layoutOverlay()
        layoutControls()
        applyPreviewRotation()
        applyVideoOutputRotation()
    }

    private func layoutOverlay() {
        updateRegionGuides()
        positionHintLabel(in: guideRect())
    }

    private func layoutControls() {
        let bounds = view.bounds
        let safe = view.safeAreaInsets
        let landscape = bounds.width > bounds.height

        cancelButton.frame = CGRect(x: safe.left + 20, y: safe.top + 20, width: 48, height: 48)
        optionsButton.frame = CGRect(x: bounds.width - safe.right - 20 - 48, y: safe.top + 20, width: 48, height: 48)

        let shutter: CGFloat = 80
        let player = playerSideControl.intrinsicContentSize
        if landscape {
            shutterButton.frame = CGRect(x: bounds.width - safe.right - 24 - shutter,
                                         y: bounds.midY - shutter / 2, width: shutter, height: shutter)
            playerSideControl.frame = CGRect(x: bounds.width - safe.right - 22 - player.width,
                                             y: bounds.height - safe.bottom - 20 - player.height,
                                             width: player.width, height: player.height)
        } else {
            shutterButton.frame = CGRect(x: bounds.midX - shutter / 2,
                                         y: bounds.height - safe.bottom - 24 - shutter,
                                         width: shutter, height: shutter)
            playerSideControl.frame = CGRect(x: safe.left + 20, y: shutterButton.frame.midY - player.height / 2,
                                             width: player.width, height: player.height)
        }
    }

    private func overlaySafeInsets() -> UIEdgeInsets {
        let safe = view.safeAreaInsets
        if overlayAngle == 0 { return safe }
        return UIEdgeInsets(top: safe.right, left: safe.top, bottom: safe.left, right: safe.bottom)
    }

    private func guideRect() -> CGRect {
        let safe = overlayView.bounds.inset(by: overlaySafeInsets())
        let available = CGRect(x: safe.minX + 16, y: safe.minY + 12, width: safe.width - 40, height: safe.height - 24)
        let aspect: CGFloat = 4.0 / 3.0
        var size = CGSize(width: available.width, height: available.width / aspect)
        if size.height > available.height {
            size = CGSize(width: available.height * aspect, height: available.height)
        }
        return CGRect(x: available.midX - size.width / 2, y: available.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    private func applyPreviewRotation() {
        guard let coordinator = rotationCoordinator, let connection = previewLayer.connection else { return }
        let angle = coordinator.videoRotationAngleForHorizonLevelPreview
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            DispatchQueue.main.async { [weak self] in self?.onUnavailable?() }
            return
        }
        session.addInput(input)
        session.addOutput(photoOutput)
        if DeviceCapability.supportsLiveDetection {
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.setSampleBufferDelegate(liveProbe, queue: videoQueue)
            if session.canAddOutput(videoDataOutput) {
                session.addOutput(videoDataOutput)
            }
        }
        session.commitConfiguration()
        session.startRunning()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.rotationCoordinator = AVCaptureDevice.RotationCoordinator(
                device: device, previewLayer: self.previewLayer
            )
            self.applyVideoOutputRotation()
            self.shutterButton.isEnabled = true
            self.view.setNeedsLayout()
        }
    }

    private func configureControls() {
        shutterButton.isEnabled = false
        if #available(iOS 26.0, *) {
            var shutterConfig = UIButton.Configuration.clearGlass()
            shutterConfig.cornerStyle = .fixed
            shutterConfig.background.cornerRadius = 40
            shutterConfig.contentInsets = .zero
            shutterConfig.image = circleImage(diameter: 72)
            shutterButton.configuration = shutterConfig
        } else {
            shutterButton.layer.cornerRadius = 40
            shutterButton.layer.borderWidth = 4
            shutterButton.layer.borderColor = UIColor.white.cgColor
            shutterButton.setImage(circleImage(diameter: 64), for: .normal)
        }
        shutterButton.addTarget(self, action: #selector(capture), for: .touchUpInside)

        var cancelConfig = glassButtonConfiguration()
        cancelConfig.image = UIImage(systemName: "xmark",
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
        cancelConfig.cornerStyle = .fixed
        cancelConfig.background.cornerRadius = 24
        cancelButton.configuration = cancelConfig
        cancelButton.accessibilityLabel = NSLocalizedString("Shared.Cancel", comment: "")
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        hintLabel.text = NSLocalizedString("Sessions.Camera.Guide", comment: "")
        hintLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        hintLabel.textColor = .white
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 2
        hintLabel.shadowColor = UIColor.black.withAlphaComponent(0.6)
        hintLabel.shadowOffset = CGSize(width: 0, height: 1)

        isPlayer2 = UserDefaults.standard.bool(forKey: playerSideDefaultsKey)
        playerSideControl.selectedSegmentIndex = isPlayer2 ? 1 : 0
        playerSideControl.selectedSegmentTintColor = .white
        playerSideControl.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        playerSideControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 14, weight: .semibold)], for: .normal)
        playerSideControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.black, .font: UIFont.systemFont(ofSize: 14, weight: .semibold)], for: .selected)
        playerSideControl.addTarget(self, action: #selector(playerSideChanged), for: .valueChanged)

        overlayView.addSubview(hintLabel)
        view.addSubview(shutterButton)
        view.addSubview(cancelButton)
        view.addSubview(playerSideControl)

        configureOptionsButton()
    }

    private func circleImage(diameter: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter)).image { _ in
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: diameter, height: diameter)).fill()
        }.withRenderingMode(.alwaysOriginal)
    }

    private func glassButtonConfiguration() -> UIButton.Configuration {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .glass()
        } else {
            config = .plain()
            config.background.visualEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        }
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        return config
    }

    @objc private func capture() {
        shutterButton.isEnabled = false
        shutterHaptic.impactOccurred()
        let settings: AVCapturePhotoSettings
        if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        } else {
            settings = AVCapturePhotoSettings()
        }
        if let coordinator = rotationCoordinator,
           let connection = photoOutput.connection(with: .video) {
            let angle = coordinator.videoRotationAngleForHorizonLevelCapture
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
        let delegate = PhotoCaptureDelegate { [weak self] data in
            self?.handleCaptured(data)
        }
        captureDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    @objc private func cancel() {
        onCancel?()
    }

    @objc private func playerSideChanged() {
        isPlayer2 = playerSideControl.selectedSegmentIndex == 1
        UserDefaults.standard.set(isPlayer2, forKey: playerSideDefaultsKey)
        layoutOverlay()
    }

    private func handleCaptured(_ data: Data?) {
        captureDelegate = nil
        if let data {
            let staged = autoDetectEnabled ? IIDXLiveResultAccumulator.shared.snapshot() : []
            onCapture?(data, staged)
        } else {
            shutterButton.isEnabled = true
        }
    }
}

extension SessionCameraViewController {
    private var autoDetectPreference: Bool {
        get { UserDefaults.standard.object(forKey: "Sessions.Camera.AutoDetect") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "Sessions.Camera.AutoDetect") }
    }

    private var autoDetectEnabled: Bool {
        DeviceCapability.supportsLiveDetection
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
            && autoDetectPreference
    }

    private var showStagedResults: Bool {
        get { UserDefaults.standard.bool(forKey: "Sessions.Camera.ShowStagedResults") }
        set { UserDefaults.standard.set(newValue, forKey: "Sessions.Camera.ShowStagedResults") }
    }

    func configureOptionsButton() {
        var config = glassButtonConfiguration()
        config.image = UIImage(systemName: "ellipsis",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
        config.cornerStyle = .fixed
        config.background.cornerRadius = 24
        optionsButton.configuration = config
        optionsButton.showsMenuAsPrimaryAction = true
        optionsButton.menu = buildOptionsMenu()
        optionsButton.accessibilityLabel = NSLocalizedString("Sessions.Camera.Options", comment: "")
        optionsButton.isHidden = !DeviceCapability.supportsLiveDetection
        view.addSubview(optionsButton)
    }

    private func buildOptionsMenu() -> UIMenu {
        let autoTitle = NSLocalizedString("Sessions.Camera.AutoDetect", comment: "")
        let autoToggle = UIAction(title: autoTitle, state: autoDetectPreference ? .on : .off) { [weak self] _ in
            self?.toggleAutoDetect()
        }
        let stagedTitle = NSLocalizedString("Sessions.Camera.ShowStagedResults", comment: "")
        let stagedToggle = UIAction(title: stagedTitle, state: showStagedResults ? .on : .off) { [weak self] _ in
            self?.toggleStagedResults()
        }
        return UIMenu(children: [autoToggle, stagedToggle])
    }

    private func toggleAutoDetect() {
        autoDetectPreference.toggle()
        optionsButton.menu = buildOptionsMenu()
        applyLiveDetectionState()
    }

    private func applyLiveDetectionState() {
        if autoDetectEnabled {
            liveProbe.start()
            startStagedTimer()
        } else {
            liveProbe.stop()
            stopStagedTimer()
        }
    }

    @objc func powerStateDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyLiveDetectionState()
            self.optionsButton.menu = self.buildOptionsMenu()
        }
    }

    private func toggleStagedResults() {
        showStagedResults.toggle()
        optionsButton.menu = buildOptionsMenu()
        if showStagedResults { startStagedTimer() } else { stopStagedTimer() }
    }

    func configureStagedOverlay() {
        stagedOverlay.translatesAutoresizingMaskIntoConstraints = false
        stagedOverlay.isHidden = true
        view.addSubview(stagedOverlay)
        NSLayoutConstraint.activate([
            stagedOverlay.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 78.0),
            stagedOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stagedOverlay.widthAnchor.constraint(lessThanOrEqualToConstant: 280.0)
        ])
    }

    func startStagedTimer() {
        stagedTimer?.invalidate()
        guard showStagedResults else {
            stagedOverlay.isHidden = true
            return
        }
        stagedTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.stagedOverlay.update(with: IIDXLiveResultAccumulator.shared.snapshot())
        }
    }

    func stopStagedTimer() {
        stagedTimer?.invalidate()
        stagedTimer = nil
        stagedOverlay.isHidden = true
    }

    func applyVideoOutputRotation() {
        guard let coordinator = rotationCoordinator,
              let connection = videoDataOutput.connection(with: .video) else { return }
        let angle = coordinator.videoRotationAngleForHorizonLevelCapture
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    func guideCorners() -> Corners {
        let rect = guideRect()
        let inset = rect.height * guidePerspective
        if isPlayer2 {
            return Corners(topLeft: CGPoint(x: rect.minX, y: rect.minY + inset),
                           topRight: CGPoint(x: rect.maxX, y: rect.minY),
                           bottomRight: CGPoint(x: rect.maxX, y: rect.maxY),
                           bottomLeft: CGPoint(x: rect.minX, y: rect.maxY - inset))
        }
        return Corners(topLeft: CGPoint(x: rect.minX, y: rect.minY),
                       topRight: CGPoint(x: rect.maxX, y: rect.minY + inset),
                       bottomRight: CGPoint(x: rect.maxX, y: rect.maxY - inset),
                       bottomLeft: CGPoint(x: rect.minX, y: rect.maxY))
    }

    private func quadPath(_ corners: Corners, cornerRadius radius: CGFloat) -> UIBezierPath {
        let points = [corners.topLeft, corners.topRight, corners.bottomRight, corners.bottomLeft]
        let path = UIBezierPath()
        let count = points.count
        for index in 0..<count {
            let curr = points[index]
            let prev = points[(index + count - 1) % count]
            let next = points[(index + 1) % count]
            let dirPrev = unitVector(from: curr, to: prev)
            let dirNext = unitVector(from: curr, to: next)
            let clamped = min(radius, min(distance(curr, prev), distance(curr, next)) / 2)
            let start = along(curr, dirPrev, clamped)
            if index == 0 { path.move(to: start) } else { path.addLine(to: start) }
            path.addQuadCurve(to: along(curr, dirNext, clamped), controlPoint: curr)
        }
        path.close()
        return path
    }

    private func regionQuad(_ region: CGRect, in corners: Corners) -> Corners {
        let uMin = isPlayer2 ? (1 - region.minX - region.width) : region.minX
        let uMax = uMin + region.width
        let vMin = region.minY
        let vMax = region.minY + region.height
        return Corners(topLeft: bilerp(uMin, vMin, corners), topRight: bilerp(uMax, vMin, corners),
                       bottomRight: bilerp(uMax, vMax, corners), bottomLeft: bilerp(uMin, vMax, corners))
    }

    private func bilerp(_ uPos: CGFloat, _ vPos: CGFloat, _ corners: Corners) -> CGPoint {
        lerp(lerp(corners.topLeft, corners.topRight, uPos),
             lerp(corners.bottomLeft, corners.bottomRight, uPos), vPos)
    }

    private func lerp(_ start: CGPoint, _ end: CGPoint, _ fraction: CGFloat) -> CGPoint {
        CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction)
    }

    private func unitVector(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let deltaX = end.x - start.x, deltaY = end.y - start.y
        let len = max((deltaX * deltaX + deltaY * deltaY).squareRoot(), 0.0001)
        return CGPoint(x: deltaX / len, y: deltaY / len)
    }

    private func along(_ origin: CGPoint, _ dir: CGPoint, _ dist: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + dir.x * dist, y: origin.y + dir.y * dist)
    }

    private func distance(_ start: CGPoint, _ end: CGPoint) -> CGFloat {
        ((start.x - end.x) * (start.x - end.x) + (start.y - end.y) * (start.y - end.y)).squareRoot()
    }

    private func configureRegionLayer(_ layer: CAShapeLayer, color: UIColor) {
        layer.fillColor = color.withAlphaComponent(0.10).cgColor
        layer.strokeColor = color.withAlphaComponent(0.95).cgColor
        layer.lineWidth = 2
        layer.lineJoin = .round
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 2
        layer.shadowOffset = .zero
    }

    func updateRegionGuides() {
        let corners = guideCorners()
        let scoreQuad = regionQuad(scoreRegion, in: corners)
        let titleQuad = regionQuad(titleRegion, in: corners)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        scoreRegionLayer.frame = overlayView.bounds
        titleRegionLayer.frame = overlayView.bounds
        scoreRegionLayer.path = quadPath(scoreQuad, cornerRadius: 10).cgPath
        titleRegionLayer.path = quadPath(titleQuad, cornerRadius: 8).cgPath
        CATransaction.commit()
    }

    func positionHintLabel(in guide: CGRect) {
        let maxWidth = guide.width - 24
        let size = hintLabel.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        let width = min(size.width, maxWidth)
        hintLabel.frame = CGRect(x: guide.midX - width / 2, y: guide.minY + 24, width: width, height: size.height)
    }

}

struct Corners {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: @MainActor (Data?) -> Void

    init(completion: @escaping @MainActor (Data?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let data = error == nil ? photo.fileDataRepresentation() : nil
        let completion = self.completion
        Task { @MainActor in completion(data) }
    }
}
