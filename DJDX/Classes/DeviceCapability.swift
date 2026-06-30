import Foundation

enum DeviceCapability {

    // A15+ iPhones are iPhone14,x and up; iPads need Apple silicon (>= 8 GB).
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
