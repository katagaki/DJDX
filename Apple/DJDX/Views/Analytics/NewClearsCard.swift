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
                    .font(.scoreline(size: 20.0))
                    .foregroundStyle(.secondary)
            } else {
                Text("\(newClears.count)")
                    .font(.scoreline(size: 20.0))
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NewClearEntry: Identifiable, Hashable, IIDXNewEntry {
    let id = UUID()
    let songRecord: IIDXSongRecord
    let level: IIDXLevel
    let score: IIDXLevelScore
    let previousClearType: String
}
