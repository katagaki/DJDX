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
            if showProfileHeader {
                DDRProfileHeaderView()
                    .padding(.horizontal)
                    .padding(.top, 16.0)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            if showAnalytics {
                DDRAnalyticsView(model: ddrAnalyticsModel,
                                 isEditing: $isEditingAnalytics,
                                 analyticsNamespace: ddrAnalyticsNamespace)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.bottom, 8.0)
        .animation(.smooth.speed(2.0), value: showProfileHeader)
        .animation(.smooth.speed(2.0), value: showAnalytics)
    }
}
