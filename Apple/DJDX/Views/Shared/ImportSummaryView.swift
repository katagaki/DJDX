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
                        LabeledContent("ImportSummary.ImportDate") {
                            Text(summary.importDate, style: .date)
                        }
                        LabeledContent("ImportSummary.ComparedWith") {
                            if let previousImportDate = summary.previousImportDate {
                                Text(previousImportDate, style: .date)
                            } else {
                                Text("ImportSummary.NoPreviousImport")
                            }
                        }
                    }
                    if !summary.ratings.isEmpty {
                        Section("ImportSummary.Ratings") {
                            ForEach(summary.ratings) { rating in
                                ratingRow(rating)
                            }
                        }
                    }
                    if summary.previousImportDate != nil {
                        Section {
                            if summary.personalBests.isEmpty {
                                Text("ImportSummary.NoPersonalBests")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(summary.personalBests) { entry in
                                    entryRow(entry)
                                }
                            }
                        } header: {
                            HStack {
                                Text("ImportSummary.PersonalBests")
                                Spacer()
                                Text(verbatim: "\(summary.personalBests.count)")
                            }
                        }
                    }
                } else if !isLoading {
                    ContentUnavailableView("ImportSummary.Unavailable", systemImage: "tray")
                        .listRowBackground(Color.clear)
                }
            }
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

    @ViewBuilder
    func ratingRow(_ rating: ImportSummaryRating) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: rating.name)
                .fontWeight(.semibold)
            Spacer()
            if let previousValue = rating.previousValue {
                Text(verbatim: format(previousValue, digits: rating.fractionDigits))
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(verbatim: format(rating.value, digits: rating.fractionDigits))
                .fontWeight(.bold)
            if let delta = rating.delta {
                Text(verbatim: signed(delta, digits: rating.fractionDigits))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(delta > 0 ? .green : delta < 0 ? .red : .secondary)
            }
        }
        .monospacedDigit()
    }

    @ViewBuilder
    func entryRow(_ entry: ImportSummaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 6.0) {
            HStack(alignment: .firstTextBaseline, spacing: 8.0) {
                Text(verbatim: entry.chart)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(entry.chartColor)
                Text(verbatim: entry.title)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12.0) {
                    scoreChangeLabel(entry)
                    rankChangeLabels(entry)
                }
                VStack(alignment: .leading, spacing: 4.0) {
                    scoreChangeLabel(entry)
                    HStack(spacing: 12.0) {
                        rankChangeLabels(entry)
                    }
                }
            }
            .font(.caption)
            .monospacedDigit()
        }
    }

    @ViewBuilder
    func scoreChangeLabel(_ entry: ImportSummaryEntry) -> some View {
        if let score = entry.score {
            changeLabel(
                previous: entry.previousScore.map { String($0) },
                current: String(score),
                color: .primary,
                delta: entry.previousScore.map { score - $0 }
            )
        }
    }

    @ViewBuilder
    func rankChangeLabels(_ entry: ImportSummaryEntry) -> some View {
        if let lamp = entry.lamp {
            changeLabel(previous: lamp.previous, current: lamp.current, color: lamp.color)
        }
        if let grade = entry.grade {
            changeLabel(previous: grade.previous, current: grade.current, color: grade.color)
        }
    }

    @ViewBuilder
    func changeLabel(previous: String?, current: String, color: Color, delta: Int? = nil) -> some View {
        HStack(spacing: 3.0) {
            if let previous {
                Text(verbatim: previous)
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(verbatim: current)
                .fontWeight(.bold)
                .foregroundStyle(color)
            if let delta {
                Text(verbatim: "+\(delta)")
                    .foregroundStyle(.green)
            }
        }
        .fixedSize()
    }

    func format(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)))
    }

    func signed(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).sign(strategy: .always()))
    }
}
