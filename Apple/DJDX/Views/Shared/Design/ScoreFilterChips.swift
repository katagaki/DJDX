import SwiftUI

struct FilterChip<Label: View>: View {
    let isOn: Bool
    var isDimmed: Bool = false
    var fill: Color?
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            label()
                .environment(\.colorScheme, .dark)
                .lineLimit(1)
                .padding(.horizontal, 9.0)
                .frame(minWidth: 30.0, minHeight: 28.0)
                .badgeSurface(cornerRadius: 6.0, fill: fill)
                .overlay {
                    if isOn {
                        RoundedRectangle(cornerRadius: 6.0)
                            .strokeBorder(colorScheme == .dark ? Color.white : Color.black, lineWidth: 1.5)
                    }
                }
                .opacity(isDimmed ? 0.35 : 1.0)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

struct FilterTextChip: View {
    let title: Text
    let isOn: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let ink: Color = colorScheme == .dark ? .white : .black
        let paper: Color = colorScheme == .dark ? .black : .white
        Button(action: action) {
            title
                .font(.system(size: 12.0, weight: .bold))
                .lineLimit(1)
                .padding(.horizontal, 9.0)
                .frame(minWidth: 30.0, minHeight: 28.0)
                .foregroundStyle(isOn ? paper : ink)
                .background(isOn ? ink : ink.opacity(0.08), in: .rect(cornerRadius: 6.0))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

struct FilterChipGroup<Content: View>: View {
    let title: Text
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6.0) {
            title
                .cardLabel()
                .foregroundStyle(.secondary)
            FlowLayout(horizontalSpacing: 6.0, verticalSpacing: 6.0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
