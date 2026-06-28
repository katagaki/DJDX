import Compression
import Foundation

enum ZipArchive {

    enum ZipArchiveError: Error {
        case invalidArchive
        case unsupportedEntry
        case decompressionFailed
        case invalidEntryPath
    }

    static func zip(directoryAt sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        var coordinatorError: NSError?
        var operationError: Error?
        NSFileCoordinator().coordinate(
            readingItemAt: sourceURL,
            options: .forUploading,
            error: &coordinatorError
        ) { zippedURL in
            do {
                try fileManager.createDirectory(
                    at: destinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: zippedURL, to: destinationURL)
            } catch {
                operationError = error
            }
        }
        if let coordinatorError {
            throw coordinatorError
        }
        if let operationError {
            throw operationError
        }
    }

    static func unzip(fileAt archiveURL: URL, to destinationURL: URL) throws {
        let data = try Data(contentsOf: archiveURL)
        let endRecord = try endOfCentralDirectory(in: data)
        var offset = endRecord.centralDirectoryOffset
        for _ in 0..<endRecord.entryCount {
            offset = try extractEntry(at: offset, in: data, to: destinationURL)
        }
    }

    private struct EndOfCentralDirectory {
        let entryCount: Int
        let centralDirectoryOffset: Int
    }

    private static func endOfCentralDirectory(in data: Data) throws -> EndOfCentralDirectory {
        let recordSize = 22
        guard data.count >= recordSize else { throw ZipArchiveError.invalidArchive }
        let searchStart = max(0, data.count - recordSize - Int(UInt16.max))
        var offset = data.count - recordSize
        while offset >= searchStart {
            if read(UInt32.self, in: data, at: offset) == 0x06054B50 {
                let entryCount = Int(read(UInt16.self, in: data, at: offset + 10))
                let centralDirectoryOffset = Int(read(UInt32.self, in: data, at: offset + 16))
                guard entryCount != Int(UInt16.max), centralDirectoryOffset != Int(UInt32.max) else {
                    throw ZipArchiveError.unsupportedEntry
                }
                return EndOfCentralDirectory(
                    entryCount: entryCount,
                    centralDirectoryOffset: centralDirectoryOffset
                )
            }
            offset -= 1
        }
        throw ZipArchiveError.invalidArchive
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private static func extractEntry(at offset: Int, in data: Data, to destinationURL: URL) throws -> Int {
        guard offset + 46 <= data.count,
              read(UInt32.self, in: data, at: offset) == 0x02014B50 else {
            throw ZipArchiveError.invalidArchive
        }
        let compressionMethod = read(UInt16.self, in: data, at: offset + 10)
        let compressedSize = Int(read(UInt32.self, in: data, at: offset + 20))
        let uncompressedSize = Int(read(UInt32.self, in: data, at: offset + 24))
        let nameLength = Int(read(UInt16.self, in: data, at: offset + 28))
        let extraLength = Int(read(UInt16.self, in: data, at: offset + 30))
        let commentLength = Int(read(UInt16.self, in: data, at: offset + 32))
        let localHeaderOffset = Int(read(UInt32.self, in: data, at: offset + 42))
        let nextEntryOffset = offset + 46 + nameLength + extraLength + commentLength

        guard compressedSize != Int(UInt32.max),
              uncompressedSize != Int(UInt32.max),
              localHeaderOffset != Int(UInt32.max) else {
            throw ZipArchiveError.unsupportedEntry
        }
        guard offset + 46 + nameLength <= data.count,
              let name = String(
                data: data.subdata(in: (offset + 46)..<(offset + 46 + nameLength)),
                encoding: .utf8
              ) else {
            throw ZipArchiveError.invalidArchive
        }

        let pathComponents = name.split(separator: "/").map(String.init).filter { $0 != "." }
        guard !pathComponents.contains(".."), !name.hasPrefix("/") else {
            throw ZipArchiveError.invalidEntryPath
        }
        guard !pathComponents.isEmpty else { return nextEntryOffset }
        var entryURL = destinationURL
        for pathComponent in pathComponents {
            entryURL.appendPathComponent(pathComponent)
        }

        let fileManager = FileManager.default
        if name.hasSuffix("/") {
            try fileManager.createDirectory(at: entryURL, withIntermediateDirectories: true)
            return nextEntryOffset
        }

        guard localHeaderOffset + 30 <= data.count,
              read(UInt32.self, in: data, at: localHeaderOffset) == 0x04034B50 else {
            throw ZipArchiveError.invalidArchive
        }
        let localNameLength = Int(read(UInt16.self, in: data, at: localHeaderOffset + 26))
        let localExtraLength = Int(read(UInt16.self, in: data, at: localHeaderOffset + 28))
        let dataStart = localHeaderOffset + 30 + localNameLength + localExtraLength
        guard dataStart + compressedSize <= data.count else {
            throw ZipArchiveError.invalidArchive
        }
        let compressedData = data.subdata(in: dataStart..<(dataStart + compressedSize))

        let fileData: Data
        switch compressionMethod {
        case 0:
            fileData = compressedData
        case 8:
            fileData = try inflate(compressedData, uncompressedSize: uncompressedSize)
        default:
            throw ZipArchiveError.unsupportedEntry
        }

        try fileManager.createDirectory(
            at: entryURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: entryURL.path) {
            try fileManager.removeItem(at: entryURL)
        }
        try fileData.write(to: entryURL)
        return nextEntryOffset
    }

    private static func inflate(_ compressedData: Data, uncompressedSize: Int) throws -> Data {
        guard uncompressedSize > 0 else { return Data() }
        guard !compressedData.isEmpty else { throw ZipArchiveError.decompressionFailed }
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: uncompressedSize)
        defer { destinationBuffer.deallocate() }
        let decodedSize = compressedData.withUnsafeBytes { sourceBytes -> Int in
            guard let sourcePointer = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return compression_decode_buffer(
                destinationBuffer,
                uncompressedSize,
                sourcePointer,
                compressedData.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        guard decodedSize == uncompressedSize else {
            throw ZipArchiveError.decompressionFailed
        }
        return Data(bytes: destinationBuffer, count: decodedSize)
    }

    private static func read<T: FixedWidthInteger>(_ type: T.Type, in data: Data, at offset: Int) -> T {
        let size = MemoryLayout<T>.size
        guard offset >= 0, offset + size <= data.count else { return 0 }
        var value: T = 0
        for index in 0..<size {
            value |= T(data[offset + index]) << (8 * index)
        }
        return value
    }
}
