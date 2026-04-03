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
    var visibleLevels: Set<IIDXLevel>

    private func isVisible(_ level: IIDXLevel) -> Bool {
        visibleLevels.isEmpty || visibleLevels.contains(level)
    }

    var body: some View {
        HStack(alignment: .top) {
            if isVisible(.beginner),
               !isBeginnerLevelHidden,
               songRecord.beginnerScore.difficulty != 0 {
                IIDXLevelLabel(levelType: .beginner,
                               score: songRecord.beginnerScore)
            }
            if isVisible(.normal),
               songRecord.normalScore.difficulty != 0 {
                IIDXLevelLabel(levelType: .normal,
                                 score: songRecord.normalScore)
            }
            if isVisible(.hyper),
               songRecord.hyperScore.difficulty != 0 {
                IIDXLevelLabel(levelType: .hyper,
                                 score: songRecord.hyperScore)
            }
            if isVisible(.another),
               songRecord.anotherScore.difficulty != 0 {
                IIDXLevelLabel(levelType: .another,
                                 score: songRecord.anotherScore)
            }
            if isVisible(.leggendaria),
               songRecord.leggendariaScore.difficulty != 0 {
                IIDXLevelLabel(levelType: .leggendaria,
                                 score: songRecord.leggendariaScore)
            }
        }
    }
}
