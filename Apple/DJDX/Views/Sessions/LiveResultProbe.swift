import AVFoundation
import CoreImage
import QuartzCore

final class LiveResultProbe: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    private static let maxDimension: CGFloat = 1920.0
    private static let minimumInterval: CFTimeInterval = 0.3

    private let lock = NSLock()
    private var latest: CVPixelBuffer?
    private var running = false
    private var generation = 0
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private var songs: [IIDXSongCandidate] = []
    private var loadedSongs = false

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lock.lock(); latest = buffer; lock.unlock()
    }

    func start() {
        lock.lock()
        guard !running else { lock.unlock(); return }
        running = true
        generation += 1
        let generation = self.generation
        lock.unlock()
        Task.detached(priority: .userInitiated) { [weak self] in await self?.loop(generation: generation) }
    }

    func stop() {
        lock.lock()
        running = false
        latest = nil
        lock.unlock()
        IIDXLiveResultAccumulator.shared.clearLive()
    }

    private func isCurrent(_ generation: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return running && generation == self.generation
    }

    private func loop(generation: Int) async {
        if !loadedSongs {
            songs = IIDXSessionCaptureProcessor.fetchSongCandidates()
            loadedSongs = true
        }
        var lastPass: CFTimeInterval = 0
        while isCurrent(generation) {
            let sinceLastPass = CACurrentMediaTime() - lastPass
            if sinceLastPass < Self.minimumInterval {
                try? await Task.sleep(for: .seconds(Self.minimumInterval - sinceLastPass))
                continue
            }
            guard let buffer = takeLatest() else {
                try? await Task.sleep(for: .seconds(0.03))
                continue
            }
            guard let image = cgImage(from: buffer) else { continue }
            let started = CACurrentMediaTime()
            lastPass = started
            do {
                let regions = try await IIDXResultReader.detect(cgImage: image)
                guard isCurrent(generation) else { return }
                let parse = IIDXResultParser.parse(regions: regions, songs: songs)
                IIDXLiveResultAccumulator.shared.ingest(regions: regions, parse: parse, at: started)
            } catch {
                debugPrint("Live detection failed: \(error)")
            }
        }
    }

    private func takeLatest() -> CVPixelBuffer? {
        lock.lock(); defer { lock.unlock() }
        let buffer = latest; latest = nil; return buffer
    }

    private func cgImage(from buffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let extent = ciImage.extent
        let scale = min(1.0, Self.maxDimension / max(extent.width, extent.height))
        guard scale < 1.0 else { return ciContext.createCGImage(ciImage, from: extent) }
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return ciContext.createCGImage(scaled, from: scaled.extent)
    }
}
