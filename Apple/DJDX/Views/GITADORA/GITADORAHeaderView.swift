import SwiftUI

extension UnifiedView {
    @ViewBuilder
    var gitadoraHeader: some View {
        VStack(spacing: 0.0) {
            Picker("Shared.GITADORA.Instrument", selection: $gitadoraInstrument) {
                ForEach(GITADORAInstrument.allCases, id: \.self) { instrument in
                    Text(verbatim: instrument.displayName)
                        .tag(instrument)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8.0)
            if showProfileHeader {
                GITADORAProfileHeaderView()
                    .padding(.horizontal)
                    .padding(.top, 10.0)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            GITADORAAnalyticsView(model: gitadoraAnalyticsModel,
                                  isEditing: $isEditingAnalytics,
                                  analyticsNamespace: gitadoraAnalyticsNamespace)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .animation(.snappy, value: showProfileHeader)
    }
}
