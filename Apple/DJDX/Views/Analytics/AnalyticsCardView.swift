//
//  AnalyticsCardView.swift
//  DJDX
//
//  Created on 2026/02/17.
//

import SwiftUI

enum AnalyticsCardHeaderPlacement {
    case top
    case bottom
}

struct AnalyticsCardView<Content: View>: View {

    let title: Text
    let systemImage: String
    let iconColor: Color
    let contentHeight: CGFloat
    var showsHeader: Bool = true
    var headerPlacement: AnalyticsCardHeaderPlacement = .top
    var caption: LocalizedStringKey?
    let content: () -> Content

    init(cardType: AnalyticsCardType,
         showsHeader: Bool = true,
         headerPlacement: AnalyticsCardHeaderPlacement = .top,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = cardType.titleText
        self.systemImage = cardType.systemImage
        self.iconColor = cardType.iconColor
        self.contentHeight = cardType.cardContentHeight
        self.showsHeader = showsHeader
        self.headerPlacement = headerPlacement
        self.content = content
    }

    init(title: LocalizedStringKey,
         systemImage: String,
         iconColor: Color,
         contentHeight: CGFloat = 80.0,
         showsHeader: Bool = true,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = Text(title)
        self.systemImage = systemImage
        self.iconColor = iconColor
        self.contentHeight = contentHeight
        self.showsHeader = showsHeader
        self.content = content
    }

    init(verbatimTitle: String,
         systemImage: String,
         iconColor: Color,
         contentHeight: CGFloat = 80.0,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = Text(verbatim: verbatimTitle)
        self.systemImage = systemImage
        self.iconColor = iconColor
        self.contentHeight = contentHeight
        self.content = content
    }

    var summaryTitle: some View {
        title
            .cardLabel()
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    @ViewBuilder
    var body: some View {
        if showsHeader && headerPlacement == .bottom {
            VStack(alignment: .leading, spacing: 2.0) {
                content()
                    .fixedSize()
                title
                    .cardLabel()
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            .padding(.horizontal, DesignMetrics.cardPadding)
            .padding(.vertical, 4.0)
            .cardBackground()
            .environment(\.cardRailColor, iconColor)
        } else {
            stackedBody
        }
    }

    var stackedBody: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            if showsHeader {
                summaryTitle
            }
            if let caption {
                Text(caption)
                    .cardLabel()
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(height: 12.0)
            }
            content()
                .frame(height: headerPlacement == .bottom
                       ? DesignMetrics.summaryContentHeight : DesignMetrics.chartHeight(contentHeight))
        }
        .padding(DesignMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
        .environment(\.cardRailColor, showsHeader ? iconColor : nil)
    }

}

struct AnalyticsCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? 0.1 : 0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension AnalyticsCardView {
    func perLevelCaption(_ key: LocalizedStringKey) -> AnalyticsCardView {
        var copy = self
        copy.caption = key
        return copy
    }
}
