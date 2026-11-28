import SwiftUI

struct ChartNotesSection: View {

    var game: Game
    var title: String
    var chart: String
    var showsPlaySettings: Bool = false

    @State private var note: ChartNote?
    @State private var savedNote: ChartNote?

    private let database = ChartNotesDatabase.shared

    var body: some View {
        Section {
            if showsPlaySettings {
                numberRow("Scores.Notes.GreenNumber", value: binding(\.greenNumber),
                          keyboardType: .numberPad)
                numberRow("Scores.Notes.LaneCover", value: binding(\.laneCover),
                          keyboardType: .numberPad)
                numberRow("Scores.Notes.JudgmentOffset", value: binding(\.judgmentOffset),
                          keyboardType: .numbersAndPunctuation)
            }
            TextField("Scores.Notes.Placeholder", text: binding(\.text), axis: .vertical)
                .lineLimit(3...)
        } header: {
            Text("Scores.Notes")
                .sectionListHeader()
        }
        .clearSection()
        .task(id: "\(game.rawValue)|\(title)|\(chart)") {
            saveIfNeeded()
            let loaded = database.note(game: game, title: title, chart: chart)
            savedNote = loaded
            note = loaded
        }
        .task(id: note) {
            guard note != savedNote else { return }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            saveIfNeeded()
        }
        .onDisappear {
            saveIfNeeded()
        }
    }

    private func saveIfNeeded() {
        guard let note, note != savedNote else { return }
        database.save(note)
        savedNote = note
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<ChartNote, Value>) -> Binding<Value> {
        Binding {
            (note ?? ChartNote(game: game, title: title, chart: chart))[keyPath: keyPath]
        } set: { newValue in
            var updated = note ?? ChartNote(game: game, title: title, chart: chart)
            updated[keyPath: keyPath] = newValue
            note = updated
        }
    }

    private func numberRow(_ titleKey: LocalizedStringKey, value: Binding<Int?>,
                           keyboardType: UIKeyboardType) -> some View {
        LabeledContent(titleKey) {
            TextField("Scores.Notes.NotSet", value: value, format: .number)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
    }
}


struct ChartNotesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var game: Game
    var title: String
    var chart: String
    var chartLabel: String

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4.0) {
                        Text(verbatim: title)
                            .font(.headline)
                        Text(verbatim: chartLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .sectionStyle()
                ChartNotesSection(game: game, title: title, chart: chart)
            }
            .insetList()
            .navigationTitle("Scores.Notes")
            .scrollDismissesKeyboard(.immediately)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .confirm) { dismiss() }
                    } else {
                        Button("Shared.Done") { dismiss() }
                    }
                }
            }
        }
    }
}
