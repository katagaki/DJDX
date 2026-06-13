import Foundation

final class ImportGroup: Identifiable, @unchecked Sendable {
    var id: String = UUID().uuidString
    var importDate: Date = Date.distantPast
    var iidxVersion: IIDXVersion?

    init(importDate: Date, iidxVersion: IIDXVersion) {
        self.importDate = importDate
        self.iidxVersion = iidxVersion
    }
}
