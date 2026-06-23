import AVFoundation
import CoreImage
import QuartzCore

// Phase-0 measurement spike: taps live camera frames and runs the existing
// detect + parse pipeline on a self-clocked loop (next inference starts when the
// previous finishes, always on the newest frame), logging timing, frame
// resolution and per-region OCR to the console. Throwaway — drives no UI/state.
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
                let detectMs = (CACurrentMediaTime() - started) * 1000
                let parse = IIDXResultParser.parse(regions: regions, songs: songs)
                let totalMs = (CACurrentMediaTime() - started) * 1000
                report(image: image, regions: regions, parse: parse, detectMs: detectMs, totalMs: totalMs)
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

    private func report(image: CGImage,
                        regions: [DetectedRegion],
                        parse: IIDXResultParse,
                        detectMs: Double,
                        totalMs: Double) {
        let song = parse.matchedSongID != nil ? "✓" : "✗"
        let detect = String(format: "%.0f", detectMs)
        let total = String(format: "%.0f", totalMs)
        let conf = String(format: "%.2f", parse.confidence)
        var summary = "🎥 [LiveProbe] \(image.width)x\(image.height)"
        summary += " detect=\(detect)ms total=\(total)ms regions=\(regions.count) conf=\(conf)"
        summary += " song=\(song) \"\(parse.songTitle ?? "—")\" \(parse.level)♦\(parse.difficulty) \(parse.playType)"
        summary += " EX=\(parse.exScore) miss=\(parse.miss) PG=\(parse.perfectGreat) GR=\(parse.great)"
        summary += " clr=\(parse.clearType) dj=\(parse.djLevel)"
        let dump = regions
            .sorted { $0.label < $1.label }
            .map { region in
                let text = region.text.replacingOccurrences(of: "\n", with: "⏎")
                return "\(region.label)=\"\(text)\"\(region.recognitionFailed ? "‼️" : "")"
            }
            .joined(separator: " ")
        print(summary)
        print("🎥 [LiveProbe]   \(dump)")
    }
}
