import Foundation
import zlib

extension ZipArchive {

    static func zip(
        directoryAt sourceURL: URL,
        to destinationURL: URL,
        rootName: String,
        including shouldInclude: (URL) -> Bool = { _ in true }
    ) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        guard fileManager.createFile(atPath: destinationURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let output = try FileHandle(forWritingTo: destinationURL)
        defer { try? output.close() }
        var writer = ZipArchiveWriter(output: output)
        let rootPath = rootName + "/"
        try writer.addDirectory(named: rootPath, modified: .now)
        try addContents(of: sourceURL, prefix: rootPath, to: &writer, including: shouldInclude)
        try writer.finish()
    }

    private static func addContents(
        of directoryURL: URL,
        prefix: String,
        to writer: inout ZipArchiveWriter,
        including shouldInclude: (URL) -> Bool
    ) throws {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey]
        let items = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )
        for item in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            try Task.checkCancellation()
            guard shouldInclude(item) else { continue }
            let values = try item.resourceValues(forKeys: keys)
            let modified = values.contentModificationDate ?? .now
            let path = prefix + item.lastPathComponent
            if values.isDirectory == true {
                try writer.addDirectory(named: path + "/", modified: modified)
                try addContents(of: item, prefix: path + "/", to: &writer, including: shouldInclude)
            } else {
                try writer.addFile(at: item, named: path, modified: modified)
            }
        }
    }
}

private struct ZipArchiveWriter {

    static let storedExtensions: Set<String> = [
        "heic", "heif", "jpg", "jpeg", "png", "gif", "webp", "mp4", "mov", "m4a", "zip"
    ]
    static let chunkSize = 1 << 20

    private struct Entry {
        let name: Data
        let method: UInt16
        let dosTime: UInt16
        let dosDate: UInt16
        let crc: UInt32
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let offset: UInt32
        let isDirectory: Bool
    }

    let output: FileHandle
    private var entries: [Entry] = []

    init(output: FileHandle) {
        self.output = output
    }

    mutating func addDirectory(named path: String, modified: Date) throws {
        let offset = try checkedOffset()
        let (dosTime, dosDate) = Self.dosDateTime(modified)
        let entry = Entry(
            name: Data(path.utf8), method: 0, dosTime: dosTime, dosDate: dosDate,
            crc: 0, compressedSize: 0, uncompressedSize: 0, offset: offset, isDirectory: true
        )
        try output.write(contentsOf: localHeader(for: entry))
        entries.append(entry)
    }

    mutating func addFile(at url: URL, named path: String, modified: Date) throws {
        let offset = try checkedOffset()
        let method: UInt16 = Self.storedExtensions.contains(url.pathExtension.lowercased()) ? 0 : 8
        let (dosTime, dosDate) = Self.dosDateTime(modified)
        let placeholder = Entry(
            name: Data(path.utf8), method: method, dosTime: dosTime, dosDate: dosDate,
            crc: 0, compressedSize: 0, uncompressedSize: 0, offset: offset, isDirectory: false
        )
        try output.write(contentsOf: localHeader(for: placeholder))

        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        let result = method == 8 ? try writeDeflated(from: input) : try writeStored(from: input)
        guard result.compressedSize < UInt64(UInt32.max),
              result.uncompressedSize < UInt64(UInt32.max) else {
            throw ZipArchive.ZipArchiveError.unsupportedEntry
        }

        let entry = Entry(
            name: placeholder.name, method: method, dosTime: dosTime, dosDate: dosDate,
            crc: result.crc, compressedSize: UInt32(result.compressedSize),
            uncompressedSize: UInt32(result.uncompressedSize), offset: offset, isDirectory: false
        )
        let end = try output.offset()
        try output.seek(toOffset: UInt64(offset) + 14)
        var sizes = Data()
        sizes.appendLittleEndian(entry.crc)
        sizes.appendLittleEndian(entry.compressedSize)
        sizes.appendLittleEndian(entry.uncompressedSize)
        try output.write(contentsOf: sizes)
        try output.seek(toOffset: end)
        entries.append(entry)
    }

    func finish() throws {
        guard entries.count < Int(UInt16.max) else {
            throw ZipArchive.ZipArchiveError.unsupportedEntry
        }
        let directoryOffset = try checkedOffset()
        var directory = Data()
        for entry in entries {
            directory.appendLittleEndian(UInt32(0x02014B50))
            directory.appendLittleEndian(UInt16(0x0314))
            directory.appendLittleEndian(UInt16(20))
            directory.appendLittleEndian(UInt16(0x0800))
            directory.appendLittleEndian(entry.method)
            directory.appendLittleEndian(entry.dosTime)
            directory.appendLittleEndian(entry.dosDate)
            directory.appendLittleEndian(entry.crc)
            directory.appendLittleEndian(entry.compressedSize)
            directory.appendLittleEndian(entry.uncompressedSize)
            directory.appendLittleEndian(UInt16(entry.name.count))
            directory.appendLittleEndian(UInt16(0))
            directory.appendLittleEndian(UInt16(0))
            directory.appendLittleEndian(UInt16(0))
            directory.appendLittleEndian(UInt16(0))
            let mode: UInt32 = entry.isDirectory ? 0o040755 : 0o100644
            directory.appendLittleEndian((mode << 16) | (entry.isDirectory ? 0x10 : 0))
            directory.appendLittleEndian(entry.offset)
            directory.append(entry.name)
        }
        guard UInt64(directoryOffset) + UInt64(directory.count) < UInt64(UInt32.max) else {
            throw ZipArchive.ZipArchiveError.unsupportedEntry
        }
        var endRecord = Data()
        endRecord.appendLittleEndian(UInt32(0x06054B50))
        endRecord.appendLittleEndian(UInt16(0))
        endRecord.appendLittleEndian(UInt16(0))
        endRecord.appendLittleEndian(UInt16(entries.count))
        endRecord.appendLittleEndian(UInt16(entries.count))
        endRecord.appendLittleEndian(UInt32(directory.count))
        endRecord.appendLittleEndian(directoryOffset)
        endRecord.appendLittleEndian(UInt16(0))
        try output.write(contentsOf: directory)
        try output.write(contentsOf: endRecord)
    }

    // MARK: Entry Data

    private struct WriteResult {
        var crc: UInt32 = 0
        var compressedSize: UInt64 = 0
        var uncompressedSize: UInt64 = 0
    }

    private func writeStored(from input: FileHandle) throws -> WriteResult {
        var result = WriteResult()
        var crc: uLong = 0
        while let chunk = try input.read(upToCount: Self.chunkSize), !chunk.isEmpty {
            try Task.checkCancellation()
            crc = Self.crc(crc, chunk)
            try output.write(contentsOf: chunk)
            result.uncompressedSize += UInt64(chunk.count)
        }
        result.crc = UInt32(truncatingIfNeeded: crc)
        result.compressedSize = result.uncompressedSize
        return result
    }

    private func writeDeflated(from input: FileHandle) throws -> WriteResult {
        var stream = z_stream()
        guard deflateInit2_(
            &stream, Z_BEST_SPEED, Z_DEFLATED, -MAX_WBITS, 8, Z_DEFAULT_STRATEGY,
            ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)
        ) == Z_OK else {
            throw ZipArchive.ZipArchiveError.compressionFailed
        }
        defer { deflateEnd(&stream) }
        let buffer = UnsafeMutablePointer<Bytef>.allocate(capacity: Self.chunkSize)
        defer { buffer.deallocate() }

        var result = WriteResult()
        var crc: uLong = 0
        var isFinished = false
        while !isFinished {
            try Task.checkCancellation()
            let chunk = try input.read(upToCount: Self.chunkSize) ?? Data()
            isFinished = chunk.isEmpty
            crc = Self.crc(crc, chunk)
            result.uncompressedSize += UInt64(chunk.count)
            try chunk.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
                stream.next_in = UnsafeMutablePointer(
                    mutating: rawBuffer.bindMemory(to: Bytef.self).baseAddress
                )
                stream.avail_in = uInt(rawBuffer.count)
                repeat {
                    stream.next_out = buffer
                    stream.avail_out = uInt(Self.chunkSize)
                    guard deflate(&stream, isFinished ? Z_FINISH : Z_NO_FLUSH) != Z_STREAM_ERROR else {
                        throw ZipArchive.ZipArchiveError.compressionFailed
                    }
                    let produced = Self.chunkSize - Int(stream.avail_out)
                    if produced > 0 {
                        try output.write(contentsOf: Data(
                            bytesNoCopy: buffer, count: produced, deallocator: .none
                        ))
                        result.compressedSize += UInt64(produced)
                    }
                } while stream.avail_out == 0
            }
        }
        result.crc = UInt32(truncatingIfNeeded: crc)
        return result
    }

    // MARK: Helpers

    private func checkedOffset() throws -> UInt32 {
        let offset = try output.offset()
        guard offset < UInt64(UInt32.max) else {
            throw ZipArchive.ZipArchiveError.unsupportedEntry
        }
        return UInt32(offset)
    }

    private func localHeader(for entry: Entry) -> Data {
        var header = Data()
        header.appendLittleEndian(UInt32(0x04034B50))
        header.appendLittleEndian(UInt16(20))
        header.appendLittleEndian(UInt16(0x0800))
        header.appendLittleEndian(entry.method)
        header.appendLittleEndian(entry.dosTime)
        header.appendLittleEndian(entry.dosDate)
        header.appendLittleEndian(entry.crc)
        header.appendLittleEndian(entry.compressedSize)
        header.appendLittleEndian(entry.uncompressedSize)
        header.appendLittleEndian(UInt16(entry.name.count))
        header.appendLittleEndian(UInt16(0))
        header.append(entry.name)
        return header
    }

    private static func crc(_ crc: uLong, _ data: Data) -> uLong {
        guard !data.isEmpty else { return crc }
        return data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
            crc32(crc, rawBuffer.bindMemory(to: Bytef.self).baseAddress, uInt(rawBuffer.count))
        }
    }

    private static func dosDateTime(_ date: Date) -> (time: UInt16, date: UInt16) {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date
        )
        let year = max(0, (components.year ?? 1980) - 1980)
        let time = ((components.hour ?? 0) << 11) | ((components.minute ?? 0) << 5)
            | ((components.second ?? 0) / 2)
        let day = (year << 9) | ((components.month ?? 1) << 5) | (components.day ?? 1)
        return (UInt16(truncatingIfNeeded: time), UInt16(truncatingIfNeeded: day))
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
