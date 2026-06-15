import SwiftUI

extension UnifiedView {
    @ViewBuilder
    var ddrHeader: some View {
        VStack(spacing: 0.0) {
            Picker("Shared.PlayType", selection: $ddrStyleToShow) {
                Text(verbatim: "SINGLE")
                    .tag(DDRPlayStyle.single)
                Text(verbatim: "DOUBLE")
                    .tag(DDRPlayStyle.double)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8.0)
        }
        .padding(.bottom, 8.0)
    }
}
