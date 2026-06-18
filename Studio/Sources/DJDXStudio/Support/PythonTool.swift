import Foundation

enum PythonTool {
    static func resolveUV() -> String? {
        let candidates = [
            "/opt/homebrew/bin/uv", "/usr/local/bin/uv",
            "\(NSHomeDirectory())/.local/bin/uv",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    // Runs `uv` to completion off the main thread, streaming stdout/stderr chunks
    // to `onLine`, and returns the exit code (-1 if it couldn't be launched).
    static func run(_ uv: String, args: [String], cwd: URL,
                    onLine: @escaping @Sendable (String) -> Void) async -> Int32 {
        await Task.detached {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: uv)
            proc.arguments = args
            proc.currentDirectoryURL = cwd
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            let handle = pipe.fileHandleForReading
            do { try proc.run() } catch { return Int32(-1) }
            while true {
                let data = handle.availableData
                if data.isEmpty { break }
                if let s = String(data: data, encoding: .utf8), !s.isEmpty { onLine(s) }
            }
            proc.waitUntilExit()
            return proc.terminationStatus
        }.value
    }
}
