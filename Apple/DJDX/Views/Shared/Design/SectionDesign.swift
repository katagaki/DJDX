import SwiftUI

enum DesignMetrics {
    static let gap: CGFloat = 4.0
    static let sectionGap: CGFloat = 10.0
    static let cardPadding: CGFloat = 6.0
    static let topPadding: CGFloat = 8.0
    static let perLevelHeight: CGFloat = 48.0
    static let barHeight: CGFloat = 12.0
    static let barSegmentGap: CGFloat = 1.0
    static let profileHeight: CGFloat = 64.0
    static let emptyCardHeight: CGFloat = 56.0
    static let sessionCardSize = CGSize(width: 124.0, height: 80.0)
    static let sessionTitleSize: CGFloat = 17.0

    static func chartHeight(_ height: CGFloat) -> CGFloat {
        height >= 100.0 ? 52.0 : height
    }
}

struct SectionHeaderContext {
    let title: LocalizedStringKey
    let isCollapsible: Bool
    let isExpanded: Bool
}

struct CardFill: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch colorScheme {
        case .light: Color.white
        default: Color.clear.background(.regularMaterial)
        }
    }
}

struct SectionChevron: View {
    let context: SectionHeaderContext
    var font: Font = .caption.weight(.bold)

    var body: some View {
        if context.isCollapsible {
            Image(systemName: "chevron.down")
                .font(font)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(context.isExpanded ? 0.0 : -90.0))
                .animation(.smooth.speed(2.0), value: context.isExpanded)
        }
    }
}

extension EnvironmentValues {
    @Entry var cardRailColor: Color?
}

struct RailCard: ViewModifier {
    @Environment(\.cardRailColor) private var railColor

    func body(content: Content) -> some View {
        content
            .padding(.leading, 3.0)
            .background { CardFill() }
            .clipShape(.rect)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(railColor ?? Color.primary.opacity(0.45))
                    .frame(width: 3.0)
            }
    }
}

extension Color {
    static let hairline = Color.primary.opacity(0.14)
}

extension View {
    func sectionHeaderTitle(size: CGFloat = 12.0) -> some View {
        self.font(.playline(size: size))
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    func cardBackground() -> some View {
        modifier(RailCard())
    }

    func emptyLabel() -> some View {
        self.font(.system(size: 10.0, weight: .bold))
            .textCase(.uppercase)
            .foregroundStyle(.tertiary)
    }

    func cardLabel() -> some View {
        self.font(.system(size: 10.0, weight: .bold))
            .textCase(.uppercase)
            .lineLimit(1)
    }
}
