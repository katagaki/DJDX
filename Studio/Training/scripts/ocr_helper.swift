// Apple Vision OCR helper for the DJDX PEAK pipeline.
//
// Compiled once via `swiftc` and cached at training/.cache/ocr_helper.
// Accepts one or more image paths; emits one JSON object per line, each:
//     {"path": "...", "regions": [{"text", "confidence", "x", "y", "w", "h"}, ...]}
// Coordinates are normalised to [0,1] with origin top-left.
//
// Note on stdout noise: the macOS TextRecognition framework can log
// "Unable to find a valid E5..." lines to stdout. Callers strip those
// using JSONDecoder.raw_decode on each output line.

import Foundation
import Vision
import AppKit

func recognize(_ path: String) -> [String: Any] {
    let url = URL(fileURLWithPath: path)
    guard let img  = NSImage(contentsOf: url),
          let tiff = img.tiffRepresentation,
          let rep  = NSBitmapImageRep(data: tiff),
          let cg   = rep.cgImage else {
        return ["path": path, "regions": [] as [Any], "error": "load_failed"]
    }
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.usesLanguageCorrection = false
    req.recognitionLanguages = ["en-US", "ja-JP"]

    do {
        try VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
    } catch {
        return ["path": path, "regions": [] as [Any], "error": "\(error)"]
    }

    var regions: [[String: Any]] = []
    for obs in (req.results ?? []) {
        guard let top = obs.topCandidates(1).first else { continue }
        let b = obs.boundingBox  // origin lower-left, normalised
        regions.append([
            "text": top.string,
            "confidence": top.confidence,
            "x": b.origin.x,
            "y": 1.0 - b.origin.y - b.size.height,
            "w": b.size.width,
            "h": b.size.height,
        ])
    }
    return ["path": path, "regions": regions]
}

let paths = Array(CommandLine.arguments.dropFirst())
if paths.isEmpty {
    FileHandle.standardError.write("usage: ocr_helper <image> [<image> ...]\n".data(using: .utf8)!)
    exit(2)
}
for p in paths {
    let obj = recognize(p)
    if let data = try? JSONSerialization.data(withJSONObject: obj) {
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write("\n".data(using: .utf8)!)
    }
}
