//
//  IIDXLevelShowcase.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftUI

struct IIDXLevelShowcase: View {
    var songRecord: IIDXSongRecord

    var body: some View {
        HStack(alignment: .top) {
            if songRecord.beginnerScore.difficulty != 0 {
                IIDXLevelLabel(levelType: .beginner,
                                 score: songRecord.beginnerScore)
            }
            if songRecord.normalScore.difficulty != 0 {
                IIDXLevelLabel(levelType: .normal,
                                 score: songRecord.normalScore)
            }
            if songRecord.hyperScore.difficulty != 0 {
                IIDXLevelLabel(levelType: .hyper,
                                 score: songRecord.hyperScore)
            }
            if songRecord.anotherScore.difficulty != 0 {
                IIDXLevelLabel(levelType: .another,
                                 score: songRecord.anotherScore)
            }
            if songRecord.leggendariaScore.difficulty != 0 {
                IIDXLevelLabel(levelType: .leggendaria,
                                 score: songRecord.leggendariaScore)
            }
        }
    }
}
