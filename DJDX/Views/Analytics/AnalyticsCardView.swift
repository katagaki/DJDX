//
//  AnalyticsCardView.swift
//  DJDX
//
//  Created on 2026/02/17.
//

import SwiftUI

struct AnalyticsCardView<Content: View>: View {
    let cardType: AnalyticsCardType
    let content: () -> Content

    init(cardType: AnalyticsCardType, @ViewBuilder content: @escaping () -> Content) {
        self.cardType = cardType
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            HStack(spacing: 6.0) {
                Image(systemName: cardType.systemImage)
                    .font(.subheadline)
                    .foregroundStyle(cardType.iconColor)
                Text(LocalizedStringKey(cardType.titleKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            content()
                .frame(height: cardType.cardContentHeight)
        }
        .padding(12.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12.0, style: .continuous))
    }
}
