import Foundation

struct DDRImportGroupInfo: Identifiable, Hashable {
    let id: String
    let date: Date
    let version: DDRVersion?
}
