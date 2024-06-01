//
//  LevelDetailRow.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/01.
//

import SwiftUI

struct LevelDetailRow: View {
    var level: IIDXLevel
    var value: String

    init(level: IIDXLevel, value: String) {
        self.level = level
        self.value = value
    }

    init(level: IIDXLevel, value: Int?) {
        self.level = level
        if let value {
            self.value = String(value)
        } else {
            self.value = "-"
        }
    }

    var body: some View {
        HStack {
            Text(LocalizedStringKey(level.rawValue))
                .fontWidth(.expanded)
                .kerning(-0.2)
                .drawingGroup()
                .modifier(LevelLabelGlow(color: foregroundColor()))
            Spacer()
            Text(value)
                .foregroundStyle(
                    LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
                )
        }
        .font(.caption)
        .fontWeight(.heavy)
    }

    func foregroundColor() -> Color {
        switch level {
        case .beginner: return Color.green
        case .normal: return Color.blue
        case .hyper: return Color.orange
        case .another: return Color.red
        case .leggendaria: return Color.purple
        default: return Color.primary
        }
    }
}
