import SwiftUI
import Observation

@MainActor
@Observable
final class PythonRunner {
    private(set) var log: String = ""
    private(set) var isRunning = false
    private(set) var lastExitCode: Int32?
    private var process: Process?

    struct Command: Identifiable {
        let id = UUID()
        let title: String
        let args: [String]
    }

    static let commands: [Command] = [
        .init(title: "Prepare dataset", args: ["run", "python", "scripts/prepare_dataset.py", "--emit-classifier-crops"]),
        .init(title: "Train detector", args: ["run", "python", "scripts/train_detector.py"]),
        .init(title: "Export CoreML", args: ["run", "python", "scripts/export_coreml.py"]),
        .init(title: "Predict (.pt) next 5", args: ["run", "python", "scripts/predict.py", "--next", "5"]),
    ]

    private static func resolveUV() -> String? {
        let candidates = [
            "/opt/homebrew/bin/uv", "/usr/local/bin/uv",
            "\(NSHomeDirectory())/.local/bin/uv",
        ]
        for c in candidates where FileManager.default.isExecutableFile(atPath: c) { return c }
        return nil
    }

    func run(_ command: Command, trainingDir: URL) {
        guard !isRunning else { return }
        guard let uv = Self.resolveUV() else {
            log += "\n[error] `uv` not found. Install from https://docs.astral.sh/uv/\n"
            return
        }
        isRunning = true
        lastExitCode = nil
        log += "\n$ uv \(command.args.joined(separator: " "))\n"

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: uv)
        proc.arguments = command.args
        proc.currentDirectoryURL = trainingDir
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        process = proc

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self?.log += s }
        }
        proc.terminationHandler = { [weak self] p in
            let code = p.terminationStatus
            Task { @MainActor in
                pipe.fileHandleForReading.readabilityHandler = nil
                self?.isRunning = false
                self?.lastExitCode = code
                self?.log += "\n[exit \(code)]\n"
                self?.process = nil
            }
        }

        do {
            try proc.run()
        } catch {
            isRunning = false
            log += "\n[error] \(error.localizedDescription)\n"
        }
    }

    func stop() {
        process?.terminate()
    }

    func clear() { log = "" }
}

struct PythonRunnerView: View {
    @Environment(AppModel.self) private var model
    @State private var runner = PythonRunner()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Python quick-starts")
                .font(.headline)
            Text("Runs the existing uv workflow in training/. The app never reimplements training.")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                ForEach(PythonRunner.commands) { cmd in
                    Button(cmd.title) {
                        if let dir = model.paths?.trainingDir { runner.run(cmd, trainingDir: dir) }
                    }
                    .disabled(runner.isRunning || model.paths == nil)
                }
                Spacer()
                if runner.isRunning {
                    Button("Stop") { runner.stop() }
                    ProgressView().controlSize(.small)
                }
                Button("Clear") { runner.clear() }.disabled(runner.isRunning)
            }

            ScrollView {
                Text(runner.log.isEmpty ? "No output yet." : runner.log)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding()
    }
}
