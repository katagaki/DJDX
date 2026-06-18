import SwiftUI

struct SessionCropPreviewView: View {
    let imageData: Data
    let onAccept: (Data) -> Void
    let onRetake: () -> Void

    @State private var image: UIImage?
    @State private var normalizedCorners: [CGPoint] = []
    @State private var detectedCorners: [CGPoint]?
    @State private var dragIndex: Int?
    @State private var isDetecting: Bool = true
    @State private var detectionFailed: Bool = false
    @State private var isApplying: Bool = false

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let cropSpace = "cropSpace"

    private var isLandscape: Bool { verticalSizeClass == .compact }

    private var defaultCorners: [CGPoint] {
        [
            CGPoint(x: 0.04, y: 0.04), CGPoint(x: 0.96, y: 0.04),
            CGPoint(x: 0.96, y: 0.96), CGPoint(x: 0.04, y: 0.96)
        ]
    }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                editor(geo: geo)
            }
            .ignoresSafeArea()
            if isLandscape {
                landscapeControls
            } else {
                topBar
                bottomBar
            }
            detectingOverlay
        }
        .background(Color.black.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: dragIndex)
        .task {
            if image == nil { image = UIImage(data: imageData) }
            await runDetection()
        }
    }

    // MARK: - Editor

    @ViewBuilder
    private func editor(geo: GeometryProxy) -> some View {
        if let image {
            let rect = displayedRect(imageSize: image.size, viewSize: geo.size)
            let viewCorners = normalizedCorners.map {
                CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
            }
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                if viewCorners.count == 4 {
                    dimMask(corners: viewCorners)
                    quadOutline(corners: viewCorners)
                    cornerHandles(corners: viewCorners, displayedRect: rect)
                    if let dragIndex {
                        loupe(at: viewCorners[dragIndex], image: image, displayedRect: rect)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .coordinateSpace(.named(cropSpace))
        }
    }

    private func dimMask(corners: [CGPoint]) -> some View {
        Canvas { context, size in
            var path = Path(CGRect(origin: .zero, size: size))
            var quad = Path()
            quad.move(to: corners[0])
            corners.dropFirst().forEach { quad.addLine(to: $0) }
            quad.closeSubpath()
            path.addPath(quad)
            context.fill(path, with: .color(.black.opacity(0.55)), style: FillStyle(eoFill: true))
        }
        .allowsHitTesting(false)
    }

    private func quadOutline(corners: [CGPoint]) -> some View {
        Canvas { context, _ in
            var path = Path()
            path.move(to: corners[0])
            corners.dropFirst().forEach { path.addLine(to: $0) }
            path.closeSubpath()
            context.stroke(path, with: .color(.white.opacity(0.95)),
                           style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        }
        .allowsHitTesting(false)
    }

    private func cornerHandles(corners: [CGPoint], displayedRect rect: CGRect) -> some View {
        ForEach(0..<corners.count, id: \.self) { index in
            handle(isActive: dragIndex == index)
                .position(corners[index])
                .gesture(
                    DragGesture(minimumDistance: 0.0, coordinateSpace: .named(cropSpace))
                        .onChanged { value in
                            dragIndex = index
                            updateCorner(index, to: value.location, displayedRect: rect)
                        }
                        .onEnded { _ in dragIndex = nil }
                )
        }
    }

    private func handle(isActive: Bool) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                Circle()
                    .fill(.clear)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .overlay(Circle().fill(Color.accentColor).frame(width: 9.0, height: 9.0))
                    .frame(width: 30.0, height: 30.0)
            } else {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(.white, lineWidth: 2.0))
                    .overlay(Circle().fill(Color.accentColor).frame(width: 9.0, height: 9.0))
                    .shadow(color: .black.opacity(0.35), radius: 3.0)
                    .frame(width: 30.0, height: 30.0)
            }
        }
        .frame(width: 44.0, height: 44.0)
        .contentShape(.circle)
        .scaleEffect(isActive ? 1.25 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)
    }

    private func loupe(at point: CGPoint, image: UIImage, displayedRect rect: CGRect) -> some View {
        let diameter: CGFloat = 116.0
        let zoom: CGFloat = 2.4
        let local = CGPoint(x: point.x - rect.minX, y: point.y - rect.minY)
        let placeBelow = point.y < 160.0
        let center = CGPoint(
            x: min(max(point.x, rect.minX + diameter / 2.0), rect.maxX - diameter / 2.0),
            y: placeBelow ? point.y + diameter / 2.0 + 40.0 : point.y - diameter / 2.0 - 40.0
        )
        return Color.black
            .frame(width: diameter, height: diameter)
            .overlay(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: rect.width, height: rect.height)
                    .scaleEffect(zoom, anchor: .topLeading)
                    .offset(x: diameter / 2.0 - local.x * zoom, y: diameter / 2.0 - local.y * zoom)
            }
            .clipShape(Circle())
            .overlay { crosshair }
            .overlay { Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2.0) }
            .shadow(color: .black.opacity(0.45), radius: 10.0, y: 4.0)
            .position(center)
            .allowsHitTesting(false)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
    }

    private var crosshair: some View {
        ZStack {
            Rectangle().fill(.white.opacity(0.7)).frame(width: 1.0, height: 20.0)
            Rectangle().fill(.white.opacity(0.7)).frame(width: 20.0, height: 1.0)
        }
    }

    // MARK: - Bars

    private var landscapeControls: some View {
        ZStack {
            VStack {
                instructionPill
                Spacer()
            }
            HStack {
                Spacer()
                VStack(spacing: 14.0) {
                    circleControl(systemImage: "chevron.left", prominent: false,
                                  showsSpinner: false, disabled: isApplying, action: onRetake)
                    circleControl(systemImage: "arrow.counterclockwise", prominent: false,
                                  showsSpinner: false, disabled: isApplying, action: resetCorners)
                    circleControl(systemImage: "checkmark", prominent: true,
                                  showsSpinner: isApplying, disabled: isApplying || isDetecting, action: applyAndAccept)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8.0)
        .opacity(isDetecting ? 0.0 : 1.0)
        .animation(.easeIn(duration: 0.2), value: isDetecting)
    }

    @ViewBuilder
    private func circleControl(systemImage: String, prominent: Bool, showsSpinner: Bool,
                               disabled: Bool, action: @escaping () -> Void) -> some View {
        let button = Button(action: action) {
            Group {
                if showsSpinner {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: systemImage).font(.title3.weight(.semibold))
                }
            }
            .frame(width: 30.0, height: 30.0)
        }
        .disabled(disabled)
        if #available(iOS 26.0, *) {
            if prominent {
                button.buttonStyle(.glassProminent).controlSize(.large).clipShape(.circle)
            } else {
                button.buttonStyle(.glass).controlSize(.large).clipShape(.circle)
            }
        } else {
            if prominent {
                button.buttonStyle(.borderedProminent).controlSize(.large).clipShape(.circle)
            } else {
                button.buttonStyle(.bordered).controlSize(.large).tint(.white).clipShape(.circle)
            }
        }
    }

    private var topBar: some View {
        VStack(spacing: 10.0) {
            HStack {
                Spacer()
                resetButton
            }
            instructionPill
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8.0)
        .opacity(isDetecting ? 0.0 : 1.0)
        .animation(.easeIn(duration: 0.2), value: isDetecting)
    }

    private var instructionPill: some View {
        Text(detectionFailed ? "Sessions.CropPreview.NoScreen" : "Sessions.CropPreview.Instruction")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16.0)
            .padding(.vertical, 10.0)
            .modifier(GlassPill())
    }

    @ViewBuilder
    private var resetButton: some View {
        let button = Button(action: resetCorners) {
            Image(systemName: "arrow.counterclockwise")
                .font(.body.weight(.semibold))
                .frame(width: 24.0, height: 24.0)
        }
        .disabled(isApplying)
        if #available(iOS 26.0, *) {
            button.buttonStyle(.glass).controlSize(.large).clipShape(.circle)
        } else {
            button.buttonStyle(.bordered).controlSize(.large).tint(.white).clipShape(.circle)
        }
    }

    private var bottomBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 12.0) {
                backButton
                useButton
            }
            .padding(.horizontal)
            .padding(.bottom, 8.0)
        }
        .opacity(isDetecting ? 0.0 : 1.0)
        .animation(.easeIn(duration: 0.2), value: isDetecting)
    }

    @ViewBuilder
    private var backButton: some View {
        let button = Button(action: onRetake) {
            Label("Sessions.CropPreview.Back", systemImage: "chevron.left")
                .frame(maxWidth: .infinity)
        }
        .disabled(isApplying)
        if #available(iOS 26.0, *) {
            button.buttonStyle(.glass).controlSize(.large)
        } else {
            button.buttonStyle(.bordered).controlSize(.large).tint(.white)
        }
    }

    @ViewBuilder
    private var useButton: some View {
        let button = Button(action: applyAndAccept) {
            Group {
                if isApplying {
                    ProgressView().tint(.white)
                } else {
                    Label("Sessions.CropPreview.Use", systemImage: "checkmark")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(isApplying || isDetecting)
        if #available(iOS 26.0, *) {
            button.buttonStyle(.glassProminent).controlSize(.large)
        } else {
            button.buttonStyle(.borderedProminent).controlSize(.large)
        }
    }

    @ViewBuilder
    private var detectingOverlay: some View {
        if isDetecting {
            VStack(spacing: 12.0) {
                ProgressView().tint(.white).scaleEffect(1.3)
                Text("Sessions.CropPreview.Detecting")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(24.0)
            .modifier(GlassCard())
            .transition(.opacity)
        }
    }

}

private extension SessionCropPreviewView {

    // MARK: - Geometry

    func displayedRect(imageSize: CGSize, viewSize: CGSize) -> CGRect {
        let fit = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * fit, height: imageSize.height * fit)
        return CGRect(
            x: (viewSize.width - size.width) / 2.0,
            y: (viewSize.height - size.height) / 2.0,
            width: size.width, height: size.height
        )
    }

    private func updateCorner(_ index: Int, to location: CGPoint, displayedRect rect: CGRect) {
        let normalizedX = (location.x - rect.minX) / rect.width
        let normalizedY = (location.y - rect.minY) / rect.height
        normalizedCorners[index] = CGPoint(
            x: min(max(normalizedX, 0.0), 1.0),
            y: min(max(normalizedY, 0.0), 1.0)
        )
    }

    private func resetCorners() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            normalizedCorners = detectedCorners ?? defaultCorners
        }
    }

    // MARK: - Detection & correction

    private func runDetection() async {
        let detected = await Task.detached(priority: .userInitiated) {
            ScreenCropDetector.detect(in: imageData)
        }.value
        await MainActor.run {
            if let detected {
                let corners = viewCorners(from: detected)
                detectedCorners = corners
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    normalizedCorners = corners
                    isDetecting = false
                }
            } else {
                detectedCorners = nil
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    normalizedCorners = defaultCorners
                    detectionFailed = true
                    isDetecting = false
                }
            }
        }
    }

    private func viewCorners(from screen: ScreenCropDetector.Screen) -> [CGPoint] {
        [
            CGPoint(x: screen.topLeft.x, y: 1.0 - screen.topLeft.y),
            CGPoint(x: screen.topRight.x, y: 1.0 - screen.topRight.y),
            CGPoint(x: screen.bottomRight.x, y: 1.0 - screen.bottomRight.y),
            CGPoint(x: screen.bottomLeft.x, y: 1.0 - screen.bottomLeft.y)
        ].map { CGPoint(x: min(max($0.x, 0.0), 1.0), y: min(max($0.y, 0.0), 1.0)) }
    }

    private func applyAndAccept() {
        guard normalizedCorners.count == 4 else { onAccept(imageData); return }
        isApplying = true
        let corners = normalizedCorners
        let data = imageData
        Task.detached(priority: .userInitiated) {
            let screen = ScreenCropDetector.Screen(
                topLeft: CGPoint(x: corners[0].x, y: 1.0 - corners[0].y),
                topRight: CGPoint(x: corners[1].x, y: 1.0 - corners[1].y),
                bottomRight: CGPoint(x: corners[2].x, y: 1.0 - corners[2].y),
                bottomLeft: CGPoint(x: corners[3].x, y: 1.0 - corners[3].y)
            )
            let corrected = ScreenCropDetector.perspectiveCorrect(imageData: data, screen: screen)
            await MainActor.run { onAccept(corrected ?? data) }
        }
    }
}

private struct GlassPill: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: .capsule)
                .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1.0))
        }
    }
}

private struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 20.0))
        } else {
            content
                .background(.thickMaterial, in: .rect(cornerRadius: 20.0))
        }
    }
}
