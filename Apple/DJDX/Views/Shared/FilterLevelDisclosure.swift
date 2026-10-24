import SwiftUI

struct FilterLevelDisclosure<Label: View, Content: View>: View {

    @State private var isExpanded: Bool = false
    @ViewBuilder var content: () -> Content
    @ViewBuilder var label: () -> Label

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            EmptyView()
        } label: {
            label()
        }
        if isExpanded {
            content()
                .listRowInsets(EdgeInsets())
        }
    }
}
