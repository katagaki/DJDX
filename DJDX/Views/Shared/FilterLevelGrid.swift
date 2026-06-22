import SwiftUI
import UIKit

struct FilterLevelGrid<Element: Hashable>: View {

    let items: [Element]
    let selection: Set<Element>
    let title: (Element) -> String
    let onToggle: (Element) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0.0), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0.0) {
            ForEach(items, id: \.self) { item in
                let isSelected = selection.contains(item)
                Button {
                    onToggle(item)
                } label: {
                    Text(verbatim: title(item))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44.0)
                        .background(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
                }
                .buttonStyle(.plain)
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}
