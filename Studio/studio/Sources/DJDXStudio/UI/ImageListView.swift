import SwiftUI

struct ImageListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: Binding(
            get: { model.currentImageURL },
            set: { url in
                if let url, let idx = model.images.firstIndex(of: url) { model.show(idx) }
            })
        ) {
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
            }
        }
        .listStyle(.sidebar)
    }
}
