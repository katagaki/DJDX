import Foundation

// Headless smoke test: `DJDXStudio --selftest <projectRoot>`. Exercises the
// non-UI core (schema parse, image listing, OCR, auto-label, label round-trip)
// and exits. Lets the pipeline be verified without driving the GUI.
enum SelfTest {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--selftest") else { return }
        let root = args.indices.contains(i + 1)
            ? URL(fileURLWithPath: args[i + 1], isDirectory: true)
            : ProjectRootStore.fallback
        run(root: root)
        exit(0)
    }

    private static func run(root: URL) {
        let paths = ProjectPaths(root: root)
        print("selftest root: \(root.path)")
        print("looksValid: \(paths.looksValid)")

        do {
            let schema = try SchemaLoader.load(from: paths.schemaFile)
            print("schema: \(schema.detectorClasses.count) detector, "
                  + "\(schema.rankClasses.count) rank, \(schema.clearTypeClasses.count) clear, "
                  + "imgsz=\(schema.detectorImageSize)")
        } catch {
            print("schema load FAILED: \(error.localizedDescription)")
        }

        let images = SupportedImage.list(in: paths.dataDir(.resultDetector))
        print("images: \(images.count)")

        if let first = images.first {
            let regions = OCR.recognize(url: first)
            let boxes = AutoLabel.boxes(from: regions)
            let counts = Dictionary(grouping: boxes, by: \.cls).mapValues(\.count)
            print("OCR \(first.lastPathComponent): \(regions.count) regions → \(boxes.count) boxes")
            print("  classes: \(counts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))")

            // Round-trip a label set through the JSON codec.
            let set = LabelSet(byImage: [first.lastPathComponent: boxes])
            let tmp = FileManager.default.temporaryDirectory.appending(path: "djdx_selftest_labels.json")
            do {
                try LabelStore.save(set, to: tmp)
                let back = LabelStore.loadFile(tmp)
                print("label round-trip: \(back?.byImage[first.lastPathComponent]?.count ?? -1) boxes")
                try? FileManager.default.removeItem(at: tmp)
            } catch {
                print("label round-trip FAILED: \(error.localizedDescription)")
            }

            // Live CoreML detector, if the exported model is present.
            let modelURL = paths.outputDir.appending(path: "DJDXResultDetector.mlpackage")
            if FileManager.default.fileExists(atPath: modelURL.path) {
                if let cg = ImageDecoder.load(first) {
                    do {
                        let schema = (try? SchemaLoader.load(from: paths.schemaFile)) ?? .placeholder
                        let dets = try CoreMLPipeline.detect(cg, modelURL: modelURL, schema: schema)
                        let counts = Dictionary(grouping: dets, by: \.cls).mapValues(\.count)
                        print("CoreML detect: \(dets.count) boxes")
                        print("  classes: \(counts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))")
                    } catch {
                        print("CoreML detect FAILED: \(error.localizedDescription)")
                    }
                }
            } else {
                print("CoreML detect: skipped (no DJDXResultDetector.mlpackage)")
            }
        }

        // Reader-crop emission: slice DJ-level + numeric regions from the saved
        // Result Detector labels into a temp dir (so the real Outputs/crops is
        // untouched) and report counts. Mirrors prepare_dataset.py's emit.
        if let set = LabelStore.loadFile(paths.labelsFile(.resultDetector)) {
            let tmp = FileManager.default.temporaryDirectory
                .appending(path: "djdx_selftest_crops", directoryHint: .isDirectory)
            switch CropExport.exportReaderCrops(
                labels: set.byImage, resultsDir: paths.dataDir(.resultDetector), cropsDir: tmp) {
            case .success(let s):
                print("reader crops: \(s.djLevels) DJ-level, \(s.digits) digit, "
                      + "from \(s.images) screens (\(s.missingImages) missing)")
            case .failure(let why):
                print("reader crops: \(why)")
            }
            try? FileManager.default.removeItem(at: tmp)
        } else {
            print("reader crops: skipped (no \(WorkspaceConfig.resultDetector.labelsFileName))")
        }

        print("selftest done")
    }
}
