//
//  PlayTypePicker.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/16.
//

import SwiftUI

struct PlayTypePicker: View {
    @Binding var playTypeToShow: IIDXPlayType

    var body: some View {
        Picker("Shared.PlayType", selection: $playTypeToShow) {
            Text(verbatim: "SP")
                .tag(IIDXPlayType.single)
            Text(verbatim: "DP")
                .tag(IIDXPlayType.double)
        }
        .pickerStyle(.segmented)
    }
}
