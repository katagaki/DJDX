import SwiftUI

struct IIDXClearTypeDetailRow: View {
    var title: String
    var value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title)
                .fontWidth(.expanded)
            Spacer()
            IIDXMetallicText.clearType(value)
                .fontWeight(.black)
        }
        .font(.caption)
        .fontWeight(.heavy)
    }
}
