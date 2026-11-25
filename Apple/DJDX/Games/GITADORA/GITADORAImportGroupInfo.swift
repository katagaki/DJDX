import Foundation

struct GITADORAImportGroupInfo: Identifiable, Hashable {
    let id: String
    let date: Date
    let version: GITADORAVersion?
}
