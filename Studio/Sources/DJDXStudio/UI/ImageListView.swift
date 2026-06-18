import SwiftUI

struct ImageListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selection) {
            ForEach(model.images, id: \.self) { url in
                HStack {
                    Text(url.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    let n = model.labelCount(for: url)
                    Text("\(n)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(n == 0 ? .secondary : .primary)
                }
                .tag(url)
                .contextMenu { rowMenu(for: url) }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: model.selection) { _, sel in
            // A single click selects one row — follow it in the editor. Multi-
            // selection (⌘/⇧-click) leaves the shown image alone.
            if sel.count == 1, let url = sel.first, url != model.currentImageURL,
               let idx = model.images.firstIndex(of: url) {
                model.show(idx)
            }
        }
    }

    @ViewBuilder private func rowMenu(for url: URL) -> some View {
        let count = effectiveTarget(for: url).count
        Button("Create evaluation model from selection (\(count))") {
            ensureSelected(url)
            model.createEvalModelFromSelection()
        }
        .disabled(model.isBuildingModel)

        Button("Label selection using evaluation model (\(count))") {
            ensureSelected(url)
            Task { await model.labelSelectionUsingEvalModel() }
        }
        .disabled(!model.hasEvalModel || model.isAutoLabeling)

        Divider()

        Button("Label selection using production model (\(count))") {
            ensureSelected(url)
            Task { await model.labelSelectionUsingProductionModel() }
        }
        .disabled(!model.hasProductionModel || model.isAutoLabeling)

        Divider()

        Button("Remove all labels from selection (\(count))", role: .destructive) {
            ensureSelected(url)
            model.clearSelectionLabels()
        }
    }

    private func effectiveTarget(for url: URL) -> Set<URL> {
        model.selection.contains(url) ? model.selection : [url]
    }

    private func ensureSelected(_ url: URL) {
        if !model.selection.contains(url) { model.selection = [url] }
    }
}
