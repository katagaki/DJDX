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
                                Text(hotkey(i)).font(.caption.monospaced())
                                    .frame(width: 14)
                                Text(cls).lineLimit(1)
                                Spacer()
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
    }

    private func hotkey(_ i: Int) -> String {
        i < 10 ? "\((i + 1) % 10)" : " "
    }
}
