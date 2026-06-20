import AVFoundation
import SwiftUI
import UIKit

struct SessionCameraView: UIViewControllerRepresentable {
    var onCapture: (Data) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> SessionCameraViewController {
        let controller = SessionCameraViewController()
        controller.onCapture = onCapture
        controller.onCancel = onCancel
        return controller
    }

    func updateUIViewController(_ uiViewController: SessionCameraViewController, context: Context) {}
}

final class SessionCameraViewController: UIViewController {
    var onCapture: ((Data) -> Void)?
    var onCancel: (() -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.tsubuzaki.DJDX.SessionCamera")
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let topGradient = CAGradientLayer()
    private let bottomGradient = CAGradientLayer()
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var captureDelegate: PhotoCaptureDelegate?

    private let shutterButton = UIButton(type: .custom)
    private let cancelButton = UIButton(type: .system)
    private var portraitShutterConstraints: [NSLayoutConstraint] = []
    private var landscapeShutterConstraints: [NSLayoutConstraint] = []
    private var isLandscapeLayout: Bool?

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
        configureControls()
        sessionQueue.async { [weak self] in self?.configureSession() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(deviceOrientationDidChange),
                                               name: UIDevice.orientationDidChangeNotification, object: nil)
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    @objc private func deviceOrientationDidChange() {
        applyPreviewRotation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = view.bounds
        let fade: CGFloat = 160
        topGradient.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: fade)
        bottomGradient.frame = CGRect(x: 0, y: view.bounds.height - fade, width: view.bounds.width, height: fade)
        CATransaction.commit()
        applyPreviewRotation()
        applyShutterPlacement()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.applyPreviewRotation()
        }
    }

    private func applyPreviewRotation() {
        guard let coordinator = rotationCoordinator, let connection = previewLayer.connection else { return }
        let angle = coordinator.videoRotationAngleForHorizonLevelPreview
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    private func applyShutterPlacement() {
        let landscape = view.bounds.width > view.bounds.height
        if isLandscapeLayout == landscape { return }
        isLandscapeLayout = landscape
        NSLayoutConstraint.deactivate(portraitShutterConstraints + landscapeShutterConstraints)
        NSLayoutConstraint.activate(landscape ? landscapeShutterConstraints : portraitShutterConstraints)
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        session.addOutput(photoOutput)
        session.commitConfiguration()
        session.startRunning()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.rotationCoordinator = AVCaptureDevice.RotationCoordinator(
                device: device, previewLayer: self.previewLayer
            )
            self.view.setNeedsLayout()
        }
    }

    private func configureControls() {
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
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

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        var cancelConfig = glassButtonConfiguration()
        cancelConfig.image = UIImage(systemName: "xmark",
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
        cancelConfig.cornerStyle = .fixed
        cancelConfig.background.cornerRadius = 24
        cancelButton.configuration = cancelConfig
        cancelButton.accessibilityLabel = NSLocalizedString("Shared.Cancel", comment: "")
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        view.addSubview(shutterButton)
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            shutterButton.widthAnchor.constraint(equalToConstant: 80),
            shutterButton.heightAnchor.constraint(equalToConstant: 80),

            cancelButton.widthAnchor.constraint(equalToConstant: 48),
            cancelButton.heightAnchor.constraint(equalToConstant: 48),
            cancelButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])

        portraitShutterConstraints = [
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ]
        landscapeShutterConstraints = [
            shutterButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            shutterButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24)
        ]
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

    private func handleCaptured(_ data: Data?) {
        captureDelegate = nil
        if let data {
            onCapture?(data)
        } else {
            shutterButton.isEnabled = true
        }
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
