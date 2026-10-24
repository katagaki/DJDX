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
            if !isDDRExternalDataEnabled {
                ddrBemaniWikiWarning
                    .padding(.horizontal)
                    .padding(.top, 16.0)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
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
        .animation(.smooth.speed(2.0), value: isDDRExternalDataEnabled)
        .animation(.smooth.speed(2.0), value: showProfileHeader)
        .animation(.smooth.speed(2.0), value: showAnalytics)
    }

    @ViewBuilder
    var ddrBemaniWikiWarning: some View {
        HStack(alignment: .top, spacing: 12.0) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18.0, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36.0, height: 36.0)
                .background(.orange, in: RoundedRectangle(cornerRadius: 9.0, style: .continuous))
            VStack(alignment: .leading, spacing: 3.0) {
                Text("DDR.DataSource.Warning.Title")
                    .font(.subheadline.weight(.semibold))
                Text("DDR.DataSource.Warning.Message")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("DDR.DataSource.Warning.Action") {
                    navigationManager.push(MorePath.moreExternalDataSources)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0.0)
        }
        .padding(12.0)
        .cardBackground(cornerRadius: 8.0)
    }
}
