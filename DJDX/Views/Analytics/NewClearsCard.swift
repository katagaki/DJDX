//
//  NewClearsCard.swift
//  DJDX
//
//  Created on 2026/02/17.
//

import SwiftUI

struct NewClearsCard: View {
    @Binding var newClears: [NewClearEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 4.0) {
            if newClears.isEmpty {
                Text(verbatim: "0")
                    .font(.system(size: 20.0, weight: .black))
                    .fontWidth(.expanded)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(newClears.count)")
                    .font(.system(size: 20.0, weight: .black))
                    .fontWidth(.expanded)
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NewClearEntry: Identifiable, Hashable {
    let id = UUID()
    let songTitle: String
    let songArtist: String
    let level: IIDXLevel
    let difficulty: Int
    let clearType: String
    let previousClearType: String
}
