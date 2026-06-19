import SwiftUI

extension UnifiedView {
    @ViewBuilder
    var polarisChordHeader: some View {
        VStack(spacing: 0.0) {
            if showProfileHeader {
                PolarisChordProfileHeaderView()
                    .padding(.horizontal)
                    .padding(.top, 16.0)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            if showAnalytics {
                PolarisChordAnalyticsView(model: polarisChordAnalyticsModel,
                                          isEditing: $isEditingAnalytics,
                                          analyticsNamespace: polarisChordAnalyticsNamespace)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.bottom, 8.0)
        .animation(.snappy, value: showProfileHeader)
        .animation(.smooth.speed(2.0), value: showAnalytics)
    }
}
