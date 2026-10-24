import Foundation
import TipKit

struct ImportMovedTip: Tip {
    @Parameter
    static var isOnboardingComplete: Bool = false

    var title: Text {
        Text("Tips.ImportMoved.Title")
    }
    var message: Text? {
        Text("Tips.ImportMoved.Text")
    }
    var image: Image? {
        Image(systemName: "arrow.down.circle.dotted")
    }
    var rules: [Rule] {
        #Rule(Self.$isOnboardingComplete) { $0 == true }
    }
}
