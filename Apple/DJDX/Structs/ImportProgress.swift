import Foundation

struct ImportProgress {
    var filesProcessed: Int?
    var fileCount: Int?
    var currentFileProgress: Int?
    var currentFileTotal: Int?

    init(
        _ filesProcessed: Int? = nil,
        _ fileCount: Int? = nil,
        _ currentFileProgress: Int? = nil,
        _ currentFileTotal: Int? = nil
    ) {
        self.filesProcessed = filesProcessed
        self.fileCount = fileCount
        self.currentFileProgress = currentFileProgress
        self.currentFileTotal = currentFileTotal
    }
}
