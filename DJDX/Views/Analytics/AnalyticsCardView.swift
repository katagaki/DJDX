//
//  AnalyticsCardView.swift
//  DJDX
//
//  Created on 2026/02/17.
//

import SwiftUI

struct AnalyticsCardView<Content: View>: View {
    let title: String
    let titleIsLocalized: Bool
    let systemImage: String
    let iconColor: Color
    let contentHeight: CGFloat
    let content: () -> Content

    init(cardType: AnalyticsCardType, @ViewBuilder content: @escaping () -> Content) {
        self.title = cardType.titleKey
        self.titleIsLocalized = true
        self.systemImage = cardType.systemImage
        self.iconColor = cardType.iconColor
        self.contentHeight = cardType.cardContentHeight
        self.content = content
    }

    init(title: String,
         systemImage: String,
         iconColor: Color,
         contentHeight: CGFloat = 100.0,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.titleIsLocalized = false
        self.systemImage = systemImage
        self.iconColor = iconColor
        self.contentHeight = contentHeight
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            HStack(spacing: 6.0) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(iconColor)
                Group {
                    if titleIsLocalized {
                        Text(LocalizedStringKey(title))
                    } else {
                        Text(verbatim: title)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            content()
                .frame(height: contentHeight)
        }
        .padding(12.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12.0, style: .continuous))
    }
}
