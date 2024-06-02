//
//  NoteTypeDetailRow.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/03.
//

import SwiftUI

struct NoteTypeDetailRow: View {
    var title: String
    var value: String
    var style: any ShapeStyle

    init(_ title: String, value: String, style: any ShapeStyle) {
        self.title = title
        self.value = value
        self.style = style
    }

    init(_ title: String, value: Int, style: any ShapeStyle) {
        self.title = title
        self.value = String(value)
        self.style = style
    }

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(style)
            Spacer()
            Text(value)
        }
        .fontWidth(.expanded)
        .font(.caption)
        .fontWeight(.heavy)
    }
}
