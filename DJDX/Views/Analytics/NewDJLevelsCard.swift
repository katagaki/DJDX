//
//  NewDJLevelsCard.swift
//  DJDX
//
//  Created on 2026/03/12.
//

import SwiftUI

struct NewDJLevelsCard: View {
    @Binding var newDJLevels: [NewDJLevelEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 4.0) {
            Spacer(minLength: 0)
            if newDJLevels.isEmpty {
                Text("Analytics.NoData")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(newDJLevels.count)")
                    .font(.system(size: 36.0, weight: .black))
                    .fontWidth(.expanded)
                    .foregroundStyle(.primary)
            }
        }
    }
}

struct NewDJLevelEntry: Identifiable, Hashable {
    let id = UUID()
    let songTitle: String
    let songArtist: String
    let level: IIDXLevel
    let difficulty: Int
    let djLevel: String
    let previousDJLevel: String
}
