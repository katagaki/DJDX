import Foundation
import OrderedCollections

struct CachedTrendData: Codable {
    var importGroupID: String
    var playType: IIDXPlayType
    var data: [Int: OrderedDictionary<String, Int>]
}
