import AVFoundation
import CoreImage
import QuartzCore

final class LiveResultProbe: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    private let lock = NSLock()
    private var latest: CVPixelBuffer?
    private var running = false
    private let ciContext = CIContext(options: nil)
    private var songs: [IIDXSongCandidate] = []
    private var loadedSongs = false

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lock.lock(); latest = buffer; lock.unlock()
    }

    func start() {
        guard !running else { return }
        running = true
        print("🎥 [LiveProbe] start")
        Task.detached(priority: .userInitiated) { [weak self] in await self?.loop() }
    }

    func stop() {
        running = false
        lock.lock(); latest = nil; lock.unlock()
        IIDXLiveResultAccumulator.shared.clearLive()
        print("🎥 [LiveProbe] stop")
    }

    private func loop() async {
        if !loadedSongs {
            songs = IIDXSessionCaptureProcessor.fetchSongCandidates()
            loadedSongs = true
        }
        while running {
            guard let buffer = takeLatest() else {
                try? await Task.sleep(nanoseconds: 30_000_000)
                continue
            }
            guard let image = cgImage(from: buffer) else { continue }
            let started = CACurrentMediaTime()
            do {
                let regions = try await IIDXResultReader.detect(cgImage: image)
                let parse = IIDXResultParser.parse(regions: regions, songs: songs)
                IIDXLiveResultAccumulator.shared.ingest(regions: regions, parse: parse, at: started)
            } catch {
                print("🎥 [LiveProbe] detect error: \(error)")
            }
        }
    }

    private func takeLatest() -> CVPixelBuffer? {
        lock.lock(); defer { lock.unlock() }
        let buffer = latest; latest = nil; return buffer
    }

    private func cgImage(from buffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
}
