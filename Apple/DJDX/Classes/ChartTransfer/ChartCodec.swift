import CryptoKit
import Foundation

enum ChartCodec {
    static let rowsPerBlock = 32
    static let lanes = 8
    static let payloadBytes = 16
    static let chunkBytes = 15
    static let parityBytes = 14
    static let maxBlocks = 15
    static let maxMessageBytes = maxBlocks * chunkBytes - 1
    static let erasureThreshold: Float = 0.3
    static let decodeMargin = 2
    static let whitening = Array(SHA256.hash(data: Data("DJDX-CHART1-WHITEN".utf8)))
    static let reedSolomon = ChartReedSolomon(nsym: parityBytes)

    static func checksum(_ payload: [UInt8]) -> [UInt8] {
        Array(SHA256.hash(data: Data("DJDX-CHART1".utf8) + payload).prefix(2))
    }

    static func pairingNumber(for message: [UInt8]) -> String {
        let h = Array(SHA256.hash(data: Data("DJDX-PAIR1".utf8) + message))
        let n = (UInt32(h[0]) << 24 | UInt32(h[1]) << 16 | UInt32(h[2]) << 8 | UInt32(h[3])) % 10000
        return String(format: "%04d", n)
    }

    static func symbolCells(_ i: Int) -> [Int] {
        let measure = i / 8, lane = i % 8
        return (0..<8).map { (measure * 8 + $0) * lanes + lane }
    }

    static func chart(for message: [UInt8]) -> [Bool]? {
        guard message.count <= maxMessageBytes else { return nil }
        let bytes = [UInt8(message.count)] + message
        let count = (bytes.count + chunkBytes - 1) / chunkBytes
        var bits: [Bool] = []
        for index in 0..<count {
            let part = Array(bytes[(index * chunkBytes)..<min(bytes.count, (index + 1) * chunkBytes)])
            let payload = [UInt8(index << 4 | count)] + part + [UInt8](repeating: 0, count: chunkBytes - part.count)
            bits += encodeBlock(payload)
        }
        return bits
    }

    static func encodeBlock(_ payload: [UInt8]) -> [Bool] {
        let codeword = reedSolomon.encode(payload + checksum(payload))
        var bits = [Bool](repeating: false, count: rowsPerBlock * lanes)
        for i in 0..<32 {
            let byte = codeword[i] ^ whitening[i]
            for (bit, cell) in symbolCells(i).enumerated() { bits[cell] = byte & (0x80 >> UInt8(bit)) != 0 }
        }
        return bits
    }

    static func decodeBlock(bits: [Bool], confidence: [Float]) -> [UInt8]? {
        var raw = [UInt8](repeating: 0, count: 32)
        var conf = [Float](repeating: 1, count: 32)
        for i in 0..<32 {
            var byte: UInt8 = 0
            for (bit, cell) in symbolCells(i).enumerated() {
                if bits[cell] { byte |= 0x80 >> UInt8(bit) }
                conf[i] = min(conf[i], confidence[cell])
            }
            raw[i] = byte ^ whitening[i]
        }
        let order = (0..<32).sorted { conf[$0] < conf[$1] }
        let base = order.filter { conf[$0] < erasureThreshold }.count
        let limit = parityBytes - decodeMargin
        guard base <= limit else { return nil }
        for erased in base...limit {
            let erasures = Array(order.prefix(erased))
            guard let data = try? reedSolomon.decode(raw, erasures: erasures) else { continue }
            let payload = Array(data[0..<payloadBytes])
            guard Array(data[payloadBytes...]) == checksum(payload) else { continue }
            let codeword = reedSolomon.encode(data)
            let erasedSet = Set(erasures)
            let corrected = (0..<32).filter { !erasedSet.contains($0) && codeword[$0] != raw[$0] }.count
            if erased + 2 * corrected <= limit { return payload }
        }
        return nil
    }

    static func blockIndex(_ payload: [UInt8]) -> Int { Int(payload[0] >> 4) }
    static func blockCount(_ payload: [UInt8]) -> Int { Int(payload[0] & 0x0F) }

    static func assemble(_ blocks: [Int: [UInt8]], count: Int) -> [UInt8]? {
        guard blocks.count == count else { return nil }
        var bytes: [UInt8] = []
        for i in 0..<count {
            guard let block = blocks[i] else { return nil }
            bytes += block[1...]
        }
        let length = Int(bytes[0])
        guard length < bytes.count else { return nil }
        return Array(bytes[1...length])
    }
}
