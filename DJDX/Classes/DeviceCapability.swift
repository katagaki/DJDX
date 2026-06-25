import Foundation

enum DeviceCapability {

    // Live result detection runs a continuous Core ML pipeline on camera frames,
    // which only stays cool and battery-friendly from A15 onward (iPhone 13 / SE 3).
    // It is disabled on A14 and older; those devices keep manual-shutter capture.
    // iPhone identifiers are iPhoneN,M where N >= 14 means A15 or newer. iPads have
    // no A15, so only Apple-silicon (M-series, >= 8 GB) iPads qualify.
    static let supportsLiveDetection: Bool = {
        let identifier = modelIdentifier
        if identifier.hasPrefix("iPhone") {
            guard let major = iPhoneMajorVersion(identifier) else { return false }
            return major >= 14
        }
        if identifier.hasPrefix("iPad") {
            return ProcessInfo.processInfo.physicalMemory >= UInt64(7) * 1_073_741_824
        }
        return false
    }()

    private static var modelIdentifier: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(bytes: buffer.prefix { $0 != 0 }, encoding: .utf8) ?? ""
        }
    }

    private static func iPhoneMajorVersion(_ identifier: String) -> Int? {
        Int(identifier.dropFirst("iPhone".count).prefix { $0.isNumber })
    }
}
