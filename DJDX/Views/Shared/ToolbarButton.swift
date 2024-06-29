//
//  ToolbarButton.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/22.
//

import SwiftUI

struct ToolbarButton: View {

    var icon: String
    var text: LocalizedStringKey
    var action: () -> Void
    var isSecondary: Bool = false

    init(_ text: LocalizedStringKey, icon: String, action: @escaping () -> Void) {
        self.icon = icon
        self.text = text
        self.action = action
    }

    init(_ text: LocalizedStringKey, icon: String, isSecondary: Bool, action: @escaping () -> Void) {
        self.icon = icon
        self.text = text
        self.action = action
        self.isSecondary = isSecondary
    }

    var body: some View {
        Group {
            if !isSecondary {
                Button {
                    action()
                } label: {
                    HStack(spacing: 8.0) {
                        Image(systemName: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18.0, height: 18.0)
                        Text(text)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.text)
                    .padding([.top, .bottom], 12.0)
                    .padding([.leading, .trailing], 16.0)
                    .background(.accent)
                }
            } else {
                Button {
                    action()
                } label: {
                    HStack(spacing: 8.0) {
                        Image(systemName: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18.0, height: 18.0)
                        Text(text)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.primary)
                    .padding([.top, .bottom], 12.0)
                    .padding([.leading, .trailing], 16.0)
                    .background(.primary.opacity(0.1))
                }
            }
        }
        .buttonStyle(.plain)
        .clipShape(.capsule)
    }
}
