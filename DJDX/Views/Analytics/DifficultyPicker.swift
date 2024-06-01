//
//  DifficultyPicker.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/21.
//

import SwiftUI

struct DifficultyPicker: View {
    @Binding var selection: Int
    @Binding var difficulties: [Int]

    var body: some View {
        Picker(selection: $selection.animation(.snappy.speed(2.0))) {
            ForEach(difficulties, id: \.self) { difficulty in
                Text("LEVEL \(difficulty)").tag(difficulty)
            }
        } label: {
            Text("Shared.Difficulty")
        }
    }
}
