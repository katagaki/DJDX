import SwiftUI

struct ImportSummaryView: View {

    @Environment(\.dismiss) var dismiss

    let load: () async -> ImportSummary?

    @State var summary: ImportSummary?
    @State var isLoading: Bool = true

    var body: some View {
        NavigationStack {
            List {
                if let summary {
                    Section {
                        header(summary)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    ForEach(summary.ratings) { rating in
                        Section {
                            ratingRow(rating, game: summary.game)
                        }
                    }
                    if summary.previousImportDate != nil {
                        Section {
                            countsRow(summary)
                        }
                        if summary.personalBests.isEmpty {
                            Section {
                                Text("ImportSummary.NoPersonalBests")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(summary.personalBests) { entry in
                                ImportSummaryEntrySection(entry: entry, game: summary.game)
                            }
                        }
                    }
                } else if !isLoading {
                    ContentUnavailableView("ImportSummary.Unavailable", systemImage: "tray")
                        .listRowBackground(Color.clear)
                }
            }
            .listSectionSpacing(.compact)
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .navigationTitle("ImportSummary.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .close) {
                            dismiss()
                        }
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .tint(.primary)
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
            }
            .task {
                summary = await load()
                isLoading = false
            }
        }
    }

    // MARK: Header

    @ViewBuilder
    func header(_ summary: ImportSummary) -> some View {
        VStack(alignment: .center, spacing: 8.0) {
            Text(summary.importDate, format: .dateTime.year().month().day())
                .font(.title)
                .fontWeight(.heavy)
                .fontWidth(.compressed)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Divider()
            HStack(spacing: 4.0) {
                if let previousImportDate = summary.previousImportDate {
                    Text("ImportSummary.ComparedWith")
                    Text(previousImportDate, format: .dateTime.year().month().day())
                } else {
                    Text("ImportSummary.NoPreviousImport")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8.0)
        .padding(.horizontal, 20.0)
    }

    // MARK: Ratings

    @ViewBuilder
    func ratingRow(_ rating: ImportSummaryRating, game: ImportSummaryGame) -> some View {
        VStack(alignment: .leading, spacing: 4.0) {
            HStack {
                Text(verbatim: rating.name)
                    .font(.caption)
                    .fontWeight(.heavy)
                    .fontWidth(.expanded)
                Spacer()
                if let delta = rating.delta {
                    Text(verbatim: signed(delta, digits: rating.fractionDigits))
                        .font(.caption)
                        .fontWeight(.heavy)
                        .fontWidth(.expanded)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .lastTextBaseline, spacing: 8.0) {
                Spacer(minLength: 0.0)
                ratingValue(format(rating.value, digits: rating.fractionDigits), game: game)
                    .font(.largeTitle)
            }
            .fontWidth(.expanded)
            .fontWeight(.black)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
    }

    @ViewBuilder
    func ratingValue(_ value: String, game: ImportSummaryGame) -> some View {
        switch game {
        case .sdvx:
            Text(verbatim: value)
                .sdvxGradeText(outlineWidth: 0.6)
        default:
            Text(verbatim: value)
                .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
        }
    }

    // MARK: Counts

    @ViewBuilder
    func countsRow(_ summary: ImportSummary) -> some View {
        HStack(spacing: 0.0) {
            countColumn("SCORE", count: summary.personalBests.count { $0.score != nil }, color: .cyan)
            countColumn("CLEAR TYPE", count: summary.personalBests.count { $0.lamp != nil }, color: .green)
            countColumn(summary.game.gradeTitle,
                        count: summary.personalBests.count { $0.grade != nil }, color: .yellow)
        }
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }

    @ViewBuilder
    func countColumn(_ title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4.0) {
            Text(verbatim: title)
                .font(.caption2)
                .foregroundStyle(color)
            Text(verbatim: String(count))
                .font(.title2)
                .fontWeight(.black)
                .monospacedDigit()
        }
        .fontWidth(.expanded)
        .fontWeight(.heavy)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity)
    }

    func format(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)))
    }

    func signed(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).sign(strategy: .always()))
    }
}
