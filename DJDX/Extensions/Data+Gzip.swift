//
//  Data+Gzip.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/03/08.
//

import Foundation
import Compression

extension Data {
    func gunzip() -> Data? {
        guard count > 2 else { return nil }

        // Check gzip magic number
        var firstTwoBytes: UInt16 = 0
        copyBytes(to: UnsafeMutableBufferPointer(
            start: &firstTwoBytes,
            count: 1
        ))
        guard firstTwoBytes == 0x8B1F else { return nil }

        // Skip gzip header (minimum 10 bytes)
        var headerSize = 10
        let flags = self[3]

        if headerSize >= count { return nil }

        // FEXTRA
        if flags & 0x04 != 0 {
            guard headerSize + 2 <= count else { return nil }
            let extraLength = Int(self[headerSize]) | (Int(self[headerSize + 1]) << 8)
            headerSize += 2 + extraLength
        }

        // FNAME
        if flags & 0x08 != 0 {
            while headerSize < count && self[headerSize] != 0 {
                headerSize += 1
            }
            headerSize += 1 // Skip null terminator
        }

        // FCOMMENT
        if flags & 0x10 != 0 {
            while headerSize < count && self[headerSize] != 0 {
                headerSize += 1
            }
            headerSize += 1
        }

        // FHCRC
        if flags & 0x02 != 0 {
            headerSize += 2
        }

        guard headerSize < count else { return nil }

        let compressedData = subdata(in: headerSize..<(count - 8)) // Exclude 8-byte trailer

        // Use Compression framework with zlib (raw deflate)
        let destinationBufferSize = 4 * 1024 * 1024 // 4 MB initial
        var destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationBufferSize)
        defer { destinationBuffer.deallocate() }

        let decompressedSize = compressedData.withUnsafeBytes { sourceBytes -> Int in
            guard let sourcePointer = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return compression_decode_buffer(
                destinationBuffer,
                destinationBufferSize,
                sourcePointer,
                compressedData.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard decompressedSize > 0 else {
            // Try with a larger buffer
            let largeBufferSize = 8 * 1024 * 1024
            let largeBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: largeBufferSize)
            defer { largeBuffer.deallocate() }

            let largeDecompressedSize = compressedData.withUnsafeBytes { sourceBytes -> Int in
                guard let sourcePointer = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return 0
                }
                return compression_decode_buffer(
                    largeBuffer,
                    largeBufferSize,
                    sourcePointer,
                    compressedData.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }

            guard largeDecompressedSize > 0 else { return nil }
            return Data(bytes: largeBuffer, count: largeDecompressedSize)
        }

        return Data(bytes: destinationBuffer, count: decompressedSize)
    }
}
