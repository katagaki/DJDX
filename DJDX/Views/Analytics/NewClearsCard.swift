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
                Text("Analytics.NoData")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60.0)
            } else {
                Text("\(newClears.count)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Analytics.NewClears.Subtitle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct NewClearEntry: Identifiable, Hashable {
    let id = UUID()
    let songTitle: String
    let level: IIDXLevel
    let difficulty: Int
    let clearType: String
    let previousClearType: String
}
