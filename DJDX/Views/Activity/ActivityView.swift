//
//  ActivityView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/05/29.
//

import SwiftUI

struct ActivityView: View {
    var body: some View {
        ContentUnavailableView(
            "Activity.NoData.Title",
            systemImage: "calendar",
            description: Text("Activity.NoData.Description")
        )
        .frame(maxWidth: .infinity, minHeight: 240.0)
    }
}
