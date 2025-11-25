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
                if let keyPath = level.scoreKeyPath,
                   songRecord[keyPath: keyPath].difficulty != 0,
                   level != .beginner || !isBeginnerLevelHidden {
                    IIDXLevelLabel(levelType: level, score: songRecord[keyPath: keyPath])
                }
            }
        }
    }
}
