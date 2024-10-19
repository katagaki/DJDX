//
//  MoreAppIconView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/19.
//

import Komponents
import SwiftUI

struct MoreAppIconView: View {

    let icons: [AppIcon] = [
        AppIcon("Pinky Crush"),
        AppIcon("EPOLIS", imageName: "AppIcon.31"),
        AppIcon("RESIDENT", imageName: "AppIcon.30"),
        AppIcon("CastHour", imageName: "AppIcon.29"),
        AppIcon("BISTROVER", imageName: "AppIcon.28"),
        AppIcon("HEROIC VERSE", imageName: "AppIcon.27")
    ]

    var body: some View {
        List {
            ForEach(icons, id: \.name) { icon in
                Button {
                    UIApplication.shared.setAlternateIconName(icon.imageName, completionHandler: { error in
                        if let error {
                            debugPrint(error.localizedDescription)
                        }
                    })
                } label: {
                    ListAppIconRow(icon)
                        .tint(.primary)
                }
                .contentShape(Rectangle())
            }
        }
        .navigationTitle("ViewTitle.More.Customization.AppIcon")
        .navigationBarTitleDisplayMode(.inline)
    }
}
