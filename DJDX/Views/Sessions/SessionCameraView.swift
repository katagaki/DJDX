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
    private let guideLayer = CAShapeLayer()
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
    private let scoreRegionLabel = UILabel()
    private let titleRegionLabel = UILabel()
    private let scoreRegionColor = UIColor.systemTeal
    private let titleRegionColor = UIColor.systemYellow
    private let scoreRegion = CGRect(x: 0.03, y: 0.04, width: 0.45, height: 0.92)
    private let titleRegion = CGRect(x: 0.54, y: 0.82, width: 0.44, height: 0.16)
    private let playerSideDefaultsKey = "Sessions.Camera.IsPlayer2"
    private var isPlayer2 = false

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
        guideLayer.fillColor = UIColor.clear.cgColor
        guideLayer.strokeColor = UIColor.white.withAlphaComponent(0.9).cgColor
        guideLayer.lineWidth = 3
        guideLayer.lineCap = .round
        guideLayer.shadowColor = UIColor.black.cgColor
        guideLayer.shadowOpacity = 0.4
        guideLayer.shadowRadius = 3
        guideLayer.shadowOffset = .zero
        overlayView.layer.addSublayer(guideLayer)
        configureRegionLayer(scoreRegionLayer, color: scoreRegionColor)
        configureRegionLayer(titleRegionLayer, color: titleRegionColor)
        overlayView.layer.addSublayer(scoreRegionLayer)
        overlayView.layer.addSublayer(titleRegionLayer)
        configureControls()
        sessionQueue.async { [weak self] in self?.configureSession() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        shutterHaptic.prepare()
        startGuidePulse()
        NotificationCenter.default.addObserver(self, selector: #selector(deviceOrientationDidChange),
                                               name: UIDevice.orientationDidChangeNotification, object: nil)
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if autoDetectEnabled { liveProbe.start() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        liveProbe.stop()
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        guideLayer.removeAnimation(forKey: "pulse")
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

    private func startGuidePulse() {
        guideLayer.removeAnimation(forKey: "pulse")
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.35
        pulse.duration = 1.1
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        guideLayer.add(pulse, forKey: "pulse")
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
        let bounds = overlayView.bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        guideLayer.frame = bounds
        guideLayer.path = cornerBracketPath(in: guideRect()).cgPath
        CATransaction.commit()
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
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(liveProbe, queue: videoQueue)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
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

        configureRegionLabel(scoreRegionLabel, text: NSLocalizedString("Sessions.Camera.Guide.ScoreBox", comment: ""),
                             color: scoreRegionColor)
        configureRegionLabel(titleRegionLabel, text: NSLocalizedString("Sessions.Camera.Guide.SongTitle", comment: ""),
                             color: titleRegionColor)

        overlayView.addSubview(scoreRegionLabel)
        overlayView.addSubview(titleRegionLabel)
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
        updateRegionGuides()
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
    private var autoDetectEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "Sessions.Camera.AutoDetect") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "Sessions.Camera.AutoDetect") }
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
        view.addSubview(optionsButton)
    }

    private func buildOptionsMenu() -> UIMenu {
        let title = NSLocalizedString("Sessions.Camera.AutoDetect", comment: "")
        let toggle = UIAction(title: title, state: autoDetectEnabled ? .on : .off) { [weak self] _ in
            self?.toggleAutoDetect()
        }
        return UIMenu(children: [toggle])
    }

    private func toggleAutoDetect() {
        autoDetectEnabled.toggle()
        optionsButton.menu = buildOptionsMenu()
        if autoDetectEnabled { liveProbe.start() } else { liveProbe.stop() }
    }

    func applyVideoOutputRotation() {
        guard let coordinator = rotationCoordinator,
              let connection = videoDataOutput.connection(with: .video) else { return }
        let angle = coordinator.videoRotationAngleForHorizonLevelCapture
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    func cornerBracketPath(in rect: CGRect, length: CGFloat = 30, radius: CGFloat = 14) -> UIBezierPath {
        let path = UIBezierPath()
        let minX = rect.minX, minY = rect.minY, maxX = rect.maxX, maxY = rect.maxY

        path.move(to: CGPoint(x: minX, y: minY + radius + length))
        path.addLine(to: CGPoint(x: minX, y: minY + radius))
        path.addArc(withCenter: CGPoint(x: minX + radius, y: minY + radius),
                    radius: radius, startAngle: .pi, endAngle: .pi * 1.5, clockwise: true)
        path.addLine(to: CGPoint(x: minX + radius + length, y: minY))

        path.move(to: CGPoint(x: maxX - radius - length, y: minY))
        path.addLine(to: CGPoint(x: maxX - radius, y: minY))
        path.addArc(withCenter: CGPoint(x: maxX - radius, y: minY + radius),
                    radius: radius, startAngle: .pi * 1.5, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: maxX, y: minY + radius + length))

        path.move(to: CGPoint(x: maxX, y: maxY - radius - length))
        path.addLine(to: CGPoint(x: maxX, y: maxY - radius))
        path.addArc(withCenter: CGPoint(x: maxX - radius, y: maxY - radius),
                    radius: radius, startAngle: 0, endAngle: .pi * 0.5, clockwise: true)
        path.addLine(to: CGPoint(x: maxX - radius - length, y: maxY))

        path.move(to: CGPoint(x: minX + radius + length, y: maxY))
        path.addLine(to: CGPoint(x: minX + radius, y: maxY))
        path.addArc(withCenter: CGPoint(x: minX + radius, y: maxY - radius),
                    radius: radius, startAngle: .pi * 0.5, endAngle: .pi, clockwise: true)
        path.addLine(to: CGPoint(x: minX, y: maxY - radius - length))

        return path
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

    private func configureRegionLabel(_ label: UILabel, text: String, color: UIColor) {
        label.text = text
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = color.withAlphaComponent(0.92)
        label.clipsToBounds = true
    }

    func updateRegionGuides() {
        let guide = guideRect()
        let scoreRect = denormalize(scoreRegion, in: guide)
        let titleRect = denormalize(titleRegion, in: guide)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        scoreRegionLayer.frame = overlayView.bounds
        titleRegionLayer.frame = overlayView.bounds
        scoreRegionLayer.path = UIBezierPath(roundedRect: scoreRect, cornerRadius: 10).cgPath
        titleRegionLayer.path = UIBezierPath(roundedRect: titleRect, cornerRadius: 8).cgPath
        CATransaction.commit()
        positionRegionLabel(scoreRegionLabel, in: scoreRect)
        positionRegionLabel(titleRegionLabel, in: titleRect)
    }

    private func denormalize(_ region: CGRect, in rect: CGRect) -> CGRect {
        let originX = isPlayer2 ? (1 - region.minX - region.width) : region.minX
        return CGRect(x: rect.minX + originX * rect.width,
                      y: rect.minY + region.minY * rect.height,
                      width: region.width * rect.width,
                      height: region.height * rect.height)
    }

    func positionHintLabel(in guide: CGRect) {
        let maxWidth = guide.width - 24
        let size = hintLabel.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        let width = min(size.width, maxWidth)
        hintLabel.frame = CGRect(x: guide.midX - width / 2, y: guide.minY + 24, width: width, height: size.height)
    }

    private func positionRegionLabel(_ label: UILabel, in rect: CGRect) {
        let textSize = label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                 height: CGFloat.greatestFiniteMagnitude))
        let width = textSize.width + 16
        let height = textSize.height + 7
        label.frame = CGRect(x: rect.minX + 6, y: rect.minY + 6, width: width, height: height)
        label.layer.cornerRadius = height / 2
    }
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
