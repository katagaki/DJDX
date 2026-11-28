import SwiftUI

extension UnifiedView {
    @ViewBuilder
    var polarisChordHeader: some View {
        VStack(spacing: 0.0) {
            if showProfileHeader {
                PolarisChordProfileHeaderView()
                    .padding(.horizontal)
                    .padding(.top, 10.0)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            PolarisChordAnalyticsView(model: polarisChordAnalyticsModel,
                                      isEditing: $isEditingAnalytics,
                                      analyticsNamespace: polarisChordAnalyticsNamespace)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .animation(.snappy, value: showProfileHeader)
    }
}
