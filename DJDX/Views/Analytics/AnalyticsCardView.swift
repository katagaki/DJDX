//
//  AnalyticsCardView.swift
//  DJDX
//
//  Created on 2026/02/17.
//

import SwiftUI

struct AnalyticsCardView<Content: View>: View {

    @Environment(\.colorScheme) var colorScheme

    let title: Text
    let systemImage: String
    let iconColor: Color
    let contentHeight: CGFloat
    let cornerRadius: CGFloat
    var showsHeader: Bool = true
    let content: () -> Content

    init(cardType: AnalyticsCardType, showsHeader: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.title = cardType.titleText
        self.systemImage = cardType.systemImage
        self.iconColor = cardType.iconColor
        self.contentHeight = cardType.cardContentHeight
        if #available(iOS 26.0, *) {
            self.cornerRadius = 20.0
        } else {
            self.cornerRadius = 12.0
        }
        self.showsHeader = showsHeader
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
        if #available(iOS 26.0, *) {
            self.cornerRadius = 20.0
        } else {
            self.cornerRadius = 12.0
        }
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
        if #available(iOS 26.0, *) {
            self.cornerRadius = 20.0
        } else {
            self.cornerRadius = 12.0
        }
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            if showsHeader {
                HStack(spacing: 6.0) {
                    Image(systemName: systemImage)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(iconColor)
                        .frame(width: 18.0, height: 18.0)
                    title
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            content()
                .frame(height: contentHeight)
        }
        .padding(12.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            switch colorScheme {
            case .light: Color.white
            case .dark: Color.clear.background(.regularMaterial)
            @unknown default: Color.clear
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
    }
}

struct AnalyticsCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? 0.1 : 0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func perLevelCaption(_ key: LocalizedStringKey) -> some View {
        VStack(spacing: 2.0) {
            self
            Text(key)
                .font(.caption2.bold())
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
