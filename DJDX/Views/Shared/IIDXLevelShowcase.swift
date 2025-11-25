//
//  IIDXLevelShowcase.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftUI

struct IIDXLevelShowcase: View {

    @AppStorage(wrappedValue: false, "ScoresView.BeginnerLevelHidden") var isBeginnerLevelHidden: Bool

    var songRecord: IIDXSongRecord

    var body: some View {
        HStack(alignment: .top) {
            ForEach(IIDXLevel.sorted, id: \.self) { level in
                if let keyPath = level.scoreKeyPath {
                    let score = songRecord[keyPath: keyPath]
                    if score.difficulty != 0 {
                        if level != .beginner || !isBeginnerLevelHidden {
                            IIDXLevelLabel(levelType: level, score: score)
                        }
                    }
                }
            }
        }
    }
}
