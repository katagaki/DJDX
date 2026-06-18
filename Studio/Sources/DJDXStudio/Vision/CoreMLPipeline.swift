import Foundation
import Vision
import CoreML
import CoreGraphics

// Native CoreML inference on the exported detector .mlpackage — the Swift
// mirror of scripts/predict.py. Runs the YOLO detector via Vision, then applies
// the same post-processing (positional filter, per-class NMS, mutually-exclusive
// prev/now resolution, singleton enforcement) so the output matches predict.py.
enum CoreMLPipeline {
    struct PipelineError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // Compiling an .mlpackage is slow; cache the loaded Vision model per path.
    private nonisolated(unsafe) static var cache: [String: VNCoreMLModel] = [:]
    private static let cacheLock = NSLock()

    // Drop cached models so a freshly rebuilt .mlpackage is picked up without
    // relaunching the app.
    static func invalidateCache() {
        cacheLock.lock(); defer { cacheLock.unlock() }
        cache.removeAll()
    }

    static func loadDetector(at url: URL) throws -> VNCoreMLModel {
        cacheLock.lock(); defer { cacheLock.unlock() }
        if let cached = cache[url.path] { return cached }
        let mlModel: MLModel
        do {
            let compiled = try MLModel.compileModel(at: url)
            mlModel = try MLModel(contentsOf: compiled)
        } catch {
            throw PipelineError(message: "Failed to load \(url.lastPathComponent): \(error.localizedDescription)")
        }
        let vn = try VNCoreMLModel(for: mlModel)
        cache[url.path] = vn
        return vn
    }

    // Run the detector and return post-processed boxes (normalised, top-left).
    static func detect(_ cgImage: CGImage, modelURL: URL, schema: Schema,
                       confidence: Double = 0.15) throws -> [Box] {
        let model = try loadDetector(at: modelURL)
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill   // matches training letterbox-free 768²

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let observations = (request.results as? [VNRecognizedObjectObservation]) ?? []
        var boxes: [Box] = []
        for obs in observations {
            guard let label = obs.labels.first else { continue }
            let conf = Double(label.confidence)
            if conf < confidence { continue }
            let bb = obs.boundingBox   // normalised, origin bottom-left
            boxes.append(Box(
                cls: label.identifier,
                x: Double(bb.origin.x),
                y: 1.0 - Double(bb.origin.y) - Double(bb.size.height),
                w: Double(bb.size.width),
                h: Double(bb.size.height),
                conf: conf
            ))
        }
        return DetectionPostProcess.apply(boxes)
    }
}

// Ports the cleanup logic from scripts/predict.py so live CoreML output matches
// the Python predictions the inspector already knows how to show.
enum DetectionPostProcess {
    // Field classes that only ever appear in the left result table.
    private static let leftTable: Set<String> = [
        "clear_type_prev", "clear_type_now", "dj_level_prev", "dj_level_now",
        "score_prev", "score_now", "score_delta",
        "miss_count_prev", "miss_count_now", "miss_count_delta", "pacemaker_aa",
        "judge_pgreat", "judge_great", "judge_good", "judge_bad", "judge_poor",
    ]
    private static let bottomInfo: Set<String> = [
        "song_title", "song_artist", "difficulty_label", "notes_count",
    ]
    // Mutually exclusive prev/now pairs — never overlap; keep higher conf.
    private static let exclusivePairs: [(String, String)] = [
        ("clear_type_prev", "clear_type_now"),
        ("score_prev", "score_now"),
        ("miss_count_prev", "miss_count_now"),
        ("dj_level_prev", "dj_level_now"),
    ]

    static func apply(_ boxes: [Box], iou: Double = 0.4) -> [Box] {
        var out = positionalFilter(boxes)
        out = dedupePerClass(out, iou: iou)
        out = dedupeCrossClass(out, iou: iou)
        out = enforceSingletons(out)
        return out.sorted { a, b in a.y != b.y ? a.y < b.y : a.x < b.x }
    }

    private static func iou(_ a: Box, _ b: Box) -> Double {
        let ax2 = a.x + a.w, ay2 = a.y + a.h, bx2 = b.x + b.w, by2 = b.y + b.h
        let ix1 = max(a.x, b.x), iy1 = max(a.y, b.y)
        let ix2 = min(ax2, bx2), iy2 = min(ay2, by2)
        if ix2 <= ix1 || iy2 <= iy1 { return 0 }
        let inter = (ix2 - ix1) * (iy2 - iy1)
        let union = a.w * a.h + b.w * b.h - inter
        return union > 0 ? inter / union : 0
    }

    private static func positionalFilter(_ boxes: [Box]) -> [Box] {
        boxes.filter { b in
            let xEnd = b.x + b.w
            if leftTable.contains(b.cls), xEnd > 0.60 { return false }
            if bottomInfo.contains(b.cls), b.y < 0.75 { return false }
            if b.cls == "stage_label", b.y > 0.20 || b.w < 0.10 || b.x > 0.70 { return false }
            return true
        }
    }

    private static func dedupePerClass(_ boxes: [Box], iou iouThresh: Double) -> [Box] {
        var byClass: [String: [Box]] = [:]
        for b in boxes { byClass[b.cls, default: []].append(b) }
        var kept: [Box] = []
        for group in byClass.values {
            var survivors: [Box] = []
            for b in group.sorted(by: { ($0.conf ?? 0) > ($1.conf ?? 0) })
            where !survivors.contains(where: { iou($0, b) > iouThresh }) {
                survivors.append(b)
            }
            kept.append(contentsOf: survivors)
        }
        return kept
    }

    private static func dedupeCrossClass(_ boxes: [Box], iou iouThresh: Double) -> [Box] {
        var drop = Set<Int>()
        for (aCls, bCls) in exclusivePairs {
            let aIdx = boxes.indices.filter { boxes[$0].cls == aCls }
            let bIdx = boxes.indices.filter { boxes[$0].cls == bCls }
            for i in aIdx where !drop.contains(i) {
                for j in bIdx where !drop.contains(j) {
                    if iou(boxes[i], boxes[j]) > iouThresh {
                        let loser = (boxes[i].conf ?? 0) < (boxes[j].conf ?? 0) ? i : j
                        drop.insert(loser)
                    }
                }
            }
        }
        return boxes.enumerated().filter { !drop.contains($0.offset) }.map(\.element)
    }

    // Every field appears at most once per screen — keep the top-confidence one.
    private static func enforceSingletons(_ boxes: [Box]) -> [Box] {
        var best: [String: Box] = [:]
        for b in boxes {
            if let cur = best[b.cls], (cur.conf ?? 0) >= (b.conf ?? 0) { continue }
            best[b.cls] = b
        }
        return Array(best.values)
    }
}
