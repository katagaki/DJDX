import SwiftUI

struct ChartNotesSection: View {

    var game: Game
    var title: String
    var chart: String
    var showsPlaySettings: Bool = false

    @State private var note: ChartNote?
    @State private var savedNote: ChartNote?
    @FocusState private var focusedField: Field?
    @Environment(\.colorScheme) private var colorScheme

    private let database = ChartNotesDatabase.shared

    var body: some View {
        Section {
            if showsPlaySettings {
                numberRow("Scores.Notes.GreenNumber", field: .greenNumber,
                          value: binding(\.greenNumber), keyboardType: .numberPad)
                numberRow("Scores.Notes.LaneCover", field: .laneCover,
                          value: binding(\.laneCover), keyboardType: .numberPad)
                numberRow("Scores.Notes.JudgmentOffset", field: .judgmentOffset,
                          value: binding(\.judgmentOffset), keyboardType: .numbersAndPunctuation)
            }
            TextField("Scores.Notes.Placeholder", text: binding(\.text), axis: .vertical)
                .lineLimit(3...)
                .focused($focusedField, equals: .text)
                .padding(.horizontal, 12.0)
                .padding(.vertical, 10.0)
                .background(ink.opacity(0.06), in: .rect(cornerRadius: 8.0))
                .contentShape(.rect)
                .onTapGesture { focusedField = .text }
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

    private var ink: Color { colorScheme == .dark ? .white : .black }

    private func numberRow(_ titleKey: LocalizedStringKey, field: Field, value: Binding<Int?>,
                           keyboardType: UIKeyboardType) -> some View {
        LabeledContent(titleKey) {
            TextField("Scores.Notes.NotSet", value: value, format: .number.grouping(.never))
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .focused($focusedField, equals: field)
        }
        .contentShape(.rect)
        .onTapGesture { focusedField = field }
    }

    private enum Field: Hashable {
        case greenNumber, laneCover, judgmentOffset, text
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
            .scrollDismissesKeyboard(.interactively)
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
