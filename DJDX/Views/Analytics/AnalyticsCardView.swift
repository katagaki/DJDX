//
//  AnalyticsCardView.swift
//  DJDX
//
//  Created on 2026/02/17.
//

import SwiftUI

struct AnalyticsCardView<Content: View>: View {
    let title: Text
    let systemImage: String
    let iconColor: Color
    let contentHeight: CGFloat
    let cornerRadius: CGFloat
    let content: () -> Content

    init(cardType: AnalyticsCardType, @ViewBuilder content: @escaping () -> Content) {
        self.title = cardType.titleText
        self.systemImage = cardType.systemImage
        self.iconColor = cardType.iconColor
        self.contentHeight = cardType.cardContentHeight
        if #available(iOS 26.0, *) {
            self.cornerRadius = 20.0
        } else {
            self.cornerRadius = 12.0
        }
        self.content = content
    }

    init(title: LocalizedStringKey,
         systemImage: String,
         iconColor: Color,
         contentHeight: CGFloat = 100.0,
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
        self.content = content
    }

    init(verbatimTitle: String,
         systemImage: String,
         iconColor: Color,
         contentHeight: CGFloat = 100.0,
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

    @GestureState private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            HStack(spacing: 6.0) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(iconColor)
                title
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            content()
                .frame(height: contentHeight)
        }
        .padding(12.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isPressed ? .thickMaterial : .thinMaterial)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: .infinity)
                .updating($isPressed) { isPressing, state, _ in
                    state = isPressing
                }
        )
        .animation(.easeInOut(duration: 0.15), value: isPressed)
    }
}
