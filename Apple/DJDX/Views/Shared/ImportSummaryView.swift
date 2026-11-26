import SwiftUI

struct ImportSummaryView: View {

    @Environment(\.dismiss) var dismiss

    let load: () async -> ImportSummary?

    @State var summary: ImportSummary?
    @State var isLoading: Bool = true

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0.0) {
                    if let summary {
                        if !summary.notesRadars.isEmpty || !summary.ratings.isEmpty {
                            VStack(spacing: 12.0) {
                                ForEach(summary.notesRadars) { notesRadar in
                                    ImportSummaryNotesRadarSection(notesRadar: notesRadar)
                                        .padding()
                                        .groupedInsetBackground()
                                }
                                ForEach(summary.ratings) { rating in
                                    ratingRow(rating, game: summary.game)
                                        .padding()
                                        .groupedInsetBackground()
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 16.0)
                            .padding(.bottom, 24.0)
                        }
                        if summary.previousImportDate != nil {
                            AnalyticsSectionHeader(title: "ImportSummary.PersonalBests")
                                .padding(.bottom, 12.0)
                            countsRow(summary)
                                .padding(.vertical, 12.0)
                                .groupedInsetBackground()
                                .padding(.horizontal)
                                .padding(.bottom, 24.0)
                            AnalyticsSectionHeader(title: "ViewTitle.Scores")
                                .padding(.bottom, 12.0)
                            Divider()
                            if summary.personalBests.isEmpty {
                                Text("ImportSummary.NoPersonalBests")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                            } else {
                                ForEach(summary.personalBests) { entry in
                                    ImportSummaryEntryRow(entry: entry, game: summary.game)
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background {
                AppBackgroundGradient()
            }
            .overlay {
                if isLoading {
                    ProgressView()
                } else if summary == nil {
                    ContentUnavailableView("ImportSummary.Unavailable", systemImage: "tray")
                }
            }
            .navigationTitle(navigationTitle)
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
            .onReceive(NotificationCenter.default.publisher(for: .importSummaryUpdated)) { _ in
                Task { summary = await load() }
            }
        }
    }

    var navigationTitle: Text {
        if let summary {
            Text(summary.importDate, format: .dateTime.year().month().day())
        } else {
            Text("ImportSummary.Title")
        }
    }

    // MARK: Ratings

    @ViewBuilder
    func ratingRow(_ rating: ImportSummaryRating, game: ImportSummaryGame) -> some View {
        VStack(alignment: .leading, spacing: 4.0) {
            HStack {
                Text(verbatim: rating.name)
                    .font(.caption)
                    .fontWeight(.heavy)
                Spacer()
                if let delta = rating.delta {
                    Text(verbatim: signed(delta, digits: rating.fractionDigits))
                        .font(.scoreline(.caption))
                        .foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .lastTextBaseline, spacing: 8.0) {
                Spacer(minLength: 0.0)
                ratingValue(format(rating.value, digits: rating.fractionDigits), game: game)
                    .font(.scoreline(.largeTitle))
            }
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
    }

    @ViewBuilder
    func countColumn(_ title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4.0) {
            Text(verbatim: title)
                .font(.caption2)
                .foregroundStyle(color)
            Text(verbatim: String(count))
                .font(.scoreline(.title2))
        }
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

extension View {
    func groupedInsetBackground() -> some View {
        background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 26.0))
    }
}
