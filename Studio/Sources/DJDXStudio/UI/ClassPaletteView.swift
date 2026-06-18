import SwiftUI

struct ClassPaletteView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Classes — click to arm / assign")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.top, 8)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(model.schema.labelClasses.enumerated()), id: \.element) { i, cls in
                        Button {
                            model.assignClassToSelection(cls)
                        } label: {
                            HStack(spacing: 6) {
                                Text(cls).lineLimit(1)
                                Spacer()
                                if let key = Schema.hotkey(for: i) {
                                    Text(key.uppercased())
                                        .font(.caption.monospaced().bold())
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            .padding(.vertical, 4).padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ClassColor.color(for: cls).opacity(0.85))
                            .foregroundStyle(.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(.black, lineWidth: model.currentClass == cls ? 2 : 0))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}
