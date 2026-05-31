import Foundation

struct SDVXImportGroupInfo: Identifiable, Hashable {
    let id: String
    let date: Date
    let version: SDVXVersion?
}
