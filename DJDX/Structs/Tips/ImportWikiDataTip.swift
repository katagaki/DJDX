import Foundation
import TipKit

struct ImportWikiDataTip: Tip {
    var title: Text {
        Text("Tips.ImportWikiData.Title")
    }
    var message: Text? {
        Text("Tips.ImportWikiData.Text")
    }
    var image: Image? {
        Image(systemName: "text.book.closed")
    }
}
