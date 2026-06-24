import SwiftUI

struct ImageListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selection) {
            ForEach(model.images, id: \.self) { url in
                row(for: url)
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

    // The crop workspaces show a thumbnail plus a glanceable label (the rank for
    // DJ Level, the digits read left-to-right for the DigitDetector); the Result
    // Detector keeps the compact filename + box-count row.
    @ViewBuilder private func row(for url: URL) -> some View {
        switch model.workspace {
        case .djLevel:
            thumbRow(url) {
                if let tag = model.classificationTag(for: url) {
                    Text(tag)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(ClassColor.color(for: tag))
                } else {
                    placeholder
                }
            }
        case .digitDetector:
            thumbRow(url) {
                let reading = model.digitReading(for: url)
                if reading.isEmpty {
                    placeholder
                } else {
                    Text(reading)
                        .font(.callout.monospacedDigit().weight(.medium))
                        .lineLimit(1)
                }
            }
        case .resultDetector:
            countRow(url)
        }
    }

    private func thumbRow<Trailing: View>(
        _ url: URL, @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 8) {
            ThumbnailView(url: url)
                .frame(width: 60, height: 38)
            Text(url.lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            trailing()
        }
        .padding(.vertical, 2)
    }

    private func countRow(_ url: URL) -> some View {
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
    }

    private var placeholder: some View {
        Text("—").foregroundStyle(.tertiary)
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
