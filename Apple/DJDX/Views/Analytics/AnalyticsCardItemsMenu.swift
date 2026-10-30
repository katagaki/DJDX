import SwiftUI

struct AnalyticsCardItemsMenu: View {
    let items: [String]
    let automaticItems: [String]
    @Binding var selection: Set<String>
    var limit: Int = 3
    let label: (String) -> String

    var effectiveSelection: Set<String> {
        selection.isEmpty ? Set(automaticItems) : selection
    }

    var body: some View {
        Menu {
            Section("Analytics.CardItems") {
                ForEach(items, id: \.self) { item in
                    Toggle(isOn: isShowing(item)) {
                        Text(verbatim: label(item))
                    }
                    .disabled(!effectiveSelection.contains(item) && effectiveSelection.count >= limit)
                }
            }
        } label: {
            Label("Analytics.Progress.Customize", systemImage: "slider.horizontal.3")
        }
        .menuActionDismissBehavior(.disabled)
    }

    func isShowing(_ item: String) -> Binding<Bool> {
        Binding {
            effectiveSelection.contains(item)
        } set: { isShowing in
            var newSelection = effectiveSelection
            if isShowing {
                newSelection.insert(item)
            } else {
                newSelection.remove(item)
            }
            selection = newSelection
        }
    }
}
