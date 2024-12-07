//
//  ProgressAlert.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/01.
//

import SwiftUI

struct ProgressAlert: View {

    @Environment(\.colorScheme) var colorScheme
    @Binding var title: String
    @Binding var message: String
    @Binding var percentage: Int

    var body: some View {
        ZStack(alignment: .center) {
            Color.black.opacity(colorScheme == .dark ? 0.5 : 0.2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .center, spacing: 0.0) {
                VStack(alignment: .center, spacing: 10.0) {
                    Text(LocalizedStringKey(title))
                        .bold()
                        .multilineTextAlignment(.center)
                    ProgressView(value: min(Float(percentage), 100.0), total: 100.0)
                        .progressViewStyle(.linear)
                    Text(NSLocalizedString(message, comment: "")
                        .replacingOccurrences(of: "%1", with: String(percentage)))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(.thickMaterial)
            .clipShape(.rect(cornerRadius: 16.0))
            .padding(.all, 32.0)
        }
        .transition(AnyTransition.opacity)
    }
}
