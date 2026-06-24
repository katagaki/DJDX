import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Slices the DJ-level glyph and numeric-field regions out of the labelled
// result-screen photos and writes them as JPEGs under Outputs/crops/. These are
// the raw material the user moves into Inputs/DJLevels and Inputs/DigitDetector
// to label in those workspaces — closing the loop from one trained model's
// detections into the next model's training inputs.
//
// Swift port of prepare_dataset.py's emit_crops_to_outputs: the class lists and
// the {stem}__{boxIndex}.jpg naming match it, so crops land with the same names
// the existing Inputs already use and a re-run overwrites cleanly.
enum CropExport {
    // Result-detector classes whose crops feed the two reader models. Keep in
    // sync with DJLEVEL_CLASSES / NUMERIC_CLASSES in prepare_dataset.py.
    static let djLevelClasses: Set<String> = ["dj_level_now", "dj_level_prev"]
    static let numericClasses: Set<String> = [
        "score_now", "score_prev", "score_delta",
        "miss_count_now", "miss_count_prev", "miss_count_delta",
        "pacemaker_aa",
        "judge_pgreat", "judge_great", "judge_good", "judge_bad", "judge_poor",
        "notes_count", "combo_break",
    ]

    struct Summary: Sendable {
        var djLevels = 0       // crops written to crops/DJLevels/
        var digits = 0         // crops written to crops/DigitDetector/
        var images = 0         // result screens that contributed ≥1 crop
        var missingImages = 0  // labelled names with no photo on disk
    }

    enum Outcome: Sendable {
        case success(Summary)
        case failure(String)
    }

    // Crop every DJ-level / numeric box from each labelled result image into
    // Outputs/crops/{DJLevels,DigitDetector}/{stem}__{boxIndex}.jpg. The two
    // output subfolders are wiped first so the result reflects only the current
    // labels (no stale crops from boxes since deleted or renumbered).
    static func exportReaderCrops(
        labels: [String: [Box]], resultsDir: URL, cropsDir: URL, quality: CGFloat = 0.92
    ) -> Outcome {
        let fm = FileManager.default
        let djlDir = cropsDir.appending(path: "DJLevels", directoryHint: .isDirectory)
        let digitDir = cropsDir.appending(path: "DigitDetector", directoryHint: .isDirectory)
        do {
            for dir in [djlDir, digitDir] {
                try? fm.removeItem(at: dir)
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        } catch {
            return .failure("Could not prepare Outputs/crops/: \(error.localizedDescription)")
        }

        var summary = Summary()
        // Sort names so crop numbering and the contributing-image count are
        // deterministic across runs.
        let names = labels.keys.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
        for name in names {
            let boxes = labels[name] ?? []
            guard boxes.contains(where: { isReaderClass($0.cls) }) else { continue }
            let src = resultsDir.appending(path: name)
            guard let cg = ImageDecoder.load(src) else {
                summary.missingImages += 1
                continue
            }
            let iw = cg.width, ih = cg.height
            let stem = (name as NSString).deletingPathExtension
            var wroteForImage = false
            // boxIndex is the box's position in the image's list — matches the
            // Python tool so re-runs and the existing Inputs names line up.
            for (boxIndex, box) in boxes.enumerated() {
                let dest: URL
                if djLevelClasses.contains(box.cls) { dest = djlDir }
                else if numericClasses.contains(box.cls) { dest = digitDir }
                else { continue }
                guard let crop = cropPixels(cg, box: box, width: iw, height: ih) else { continue }
                let out = dest.appending(path: "\(stem)__\(boxIndex).jpg")
                guard writeJPEG(crop, to: out, quality: quality) else { continue }
                if dest == djlDir { summary.djLevels += 1 } else { summary.digits += 1 }
                wroteForImage = true
            }
            if wroteForImage { summary.images += 1 }
        }

        if summary.djLevels == 0 && summary.digits == 0 {
            return .failure("No DJ Level or numeric regions found in the Result Detector labels.")
        }
        return .success(summary)
    }

    private static func isReaderClass(_ cls: String) -> Bool {
        djLevelClasses.contains(cls) || numericClasses.contains(cls)
    }

    // Pixel-space crop matching the editor: Box is top-left-origin normalised and
    // CGImage.cropping also uses top-left pixel coords, so the same rect applies
    // with no vertical flip (mirrors im.crop in prepare_dataset.py).
    private static func cropPixels(_ cg: CGImage, box: Box, width iw: Int, height ih: Int) -> CGImage? {
        let b = box.normalised()
        let rect = CGRect(
            x: (b.x * Double(iw)).rounded(.down),
            y: (b.y * Double(ih)).rounded(.down),
            width: (b.w * Double(iw)).rounded(),
            height: (b.h * Double(ih)).rounded()
        )
        let clamped = rect.intersection(CGRect(x: 0, y: 0, width: iw, height: ih))
        guard clamped.width >= 1, clamped.height >= 1 else { return nil }
        return cg.cropping(to: clamped)
    }

    private static func writeJPEG(_ cg: CGImage, to url: URL, quality: CGFloat) -> Bool {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(
            dest, cg, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(dest)
    }
}
