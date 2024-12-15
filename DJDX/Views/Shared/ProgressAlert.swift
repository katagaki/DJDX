//
//  ProgressAlert.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/01.
//

import SwiftUI

struct ProgressAlert: View {

    @Environment(\.colorScheme) var colorScheme
    @Environment(ProgressAlertManager.self) var progressAlertManager

    @Binding var title: String
    @Binding var message: String

    var body: some View {
        ZStack(alignment: .center) {
            Color.black.opacity(colorScheme == .dark ? 0.5 : 0.2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .center, spacing: 0.0) {
                VStack(alignment: .center, spacing: 10.0) {
                    Text(LocalizedStringKey(title))
                        .bold()
                        .multilineTextAlignment(.center)
                    ProgressView(value: min(Float(progressAlertManager.percentage), 100.0), total: 100.0)
                        .progressViewStyle(.linear)
                    Text(NSLocalizedString(message, comment: "")
                        .replacingOccurrences(of: "%1", with: String(progressAlertManager.percentage)))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(.thickMaterial)
            .clipShape(.rect(cornerRadius: 16.0))
            .padding(.all, 32.0)
        }
        .presentationBackground(.clear)
        .ignoresSafeArea(.all)
    }
}
