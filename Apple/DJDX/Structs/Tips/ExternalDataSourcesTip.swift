import Foundation
import TipKit

struct ExternalDataSourcesTip: Tip {
    var title: Text {
        Text("Tips.ExternalDataSources.Title")
    }
    var message: Text? {
        Text("Tips.ExternalDataSources.Text")
    }
    var image: Image? {
        Image(systemName: "sparkles")
    }
}
