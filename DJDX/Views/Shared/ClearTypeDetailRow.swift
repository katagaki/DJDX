//
//  ClearTypeDetailRow.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/03.
//

import SwiftUI

struct ClearTypeDetailRow: View {
    var title: String
    var value: String
    var style: any ShapeStyle

    init(_ title: String, value: String, style: any ShapeStyle) {
        self.title = title
        self.value = value
        self.style = style
    }

    var body: some View {
        HStack {
            Text(title)
                .fontWidth(.expanded)
            Spacer()
            Text(value)
                .foregroundStyle(style)
        }
        .font(.caption)
        .fontWeight(.heavy)
    }
}
