import SwiftUI

struct MoreNotesRadarView: View {

    @Environment(\.colorScheme) var colorScheme

    let spRadarData: RadarData?
    let dpRadarData: RadarData?
    var width: CGFloat?
    var maxHeight: CGFloat?
    var radarFontSize: CGFloat = 10.0
    var listFontSize: CGFloat = 12.0
    var radarPadding: CGFloat = 8.0
    var radarLabelPadding: CGFloat = 30.0
    var radarLineWidth: CGFloat = 1.5

    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var selectedPlayType: IIDXPlayType

    @State private var isShowingValues: Bool = false

    var currentRadarData: RadarData? {
        switch selectedPlayType {
        case .single: spRadarData
        case .double: dpRadarData
        }
    }

    var body: some View {
        if let radarData = currentRadarData {
            RadarChartView(radarData, isPlayerRadar: true, labelFontSize: radarFontSize,
                           lineWidth: radarLineWidth, labelPadding: radarLabelPadding)
                .padding(radarPadding)
                .frame(width: width, height: maxHeight)
                .frame(maxWidth: width == nil ? .infinity : nil, maxHeight: maxHeight)
                .contentShape(.rect)
                .onTapGesture {
                    isShowingValues = true
                }
                .popover(isPresented: $isShowingValues) {
                    valueList(for: radarData)
                        .presentationCompactAdaptation(.popover)
                }
                .animation(.smooth, value: selectedPlayType)
        }
    }

    @ViewBuilder
    func valueList(for radarData: RadarData) -> some View {
        VStack(spacing: 6.0) {
            ForEach(radarData.displayPoints(), id: \.label) { point in
                HStack(spacing: 16.0) {
                    Text(verbatim: point.label)
                        .font(.radarline(size: listFontSize))
                        .foregroundStyle(point.color)
                        .brightness(colorScheme == .light ? -0.18 : 0.0)
                        .fixedSize()
                    Spacer(minLength: 8.0)
                    Text(verbatim: String(format: "%.2f", point.value))
                        .font(.scoreline(size: listFontSize, weight: .bold))
                        .foregroundStyle(.primary)
                        .fixedSize()
                }
            }
            Divider()
                .padding(.vertical, 2.0)
            HStack(spacing: 16.0) {
                Text("More.NotesRadar.Total")
                    .font(.system(size: listFontSize, weight: .bold))
                    .fixedSize()
                Spacer(minLength: 8.0)
                Text(verbatim: String(format: "%.2f", radarData.sum()))
                    .font(.scoreline(size: listFontSize, weight: .bold))
                    .fixedSize()
            }
        }
        .padding(.horizontal, 18.0)
        .padding(.vertical, 14.0)
        .frame(minWidth: 210.0)
    }
}
