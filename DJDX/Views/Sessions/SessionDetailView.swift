import SwiftUI

struct SessionDetailView: View {
    var store: SessionStore
    var session: PlaySession

    @State private var plays: [CapturedPlay] = []

    var body: some View {
        List {
            Section("Sessions.Detail.Summary") {
                LabeledContent("Shared.Date") {
                    Text(session.startDate, format: .dateTime.year().month().day().hour().minute())
                }
                LabeledContent("Sessions.Elapsed") {
                    Text(verbatim: durationText)
                }
                LabeledContent("Sessions.Plays") {
                    Text(verbatim: "\(plays.count)")
                }
            }
            Section("Sessions.History.Plays") {
                if plays.isEmpty {
                    Text("Sessions.Empty.Title")
                        .foregroundStyle(.secondary)
                }
                ForEach(plays.reversed()) { play in
                    NavigationLink {
                        CapturedPlayDetailView(store: store, play: play)
                    } label: {
                        CapturedPlayRow(play: play)
                    }
                }
            }
        }
        .navigationTitle("Sessions.Detail.Title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { plays = store.plays(for: session) }
        .onReceive(NotificationCenter.default.publisher(for: .capturedPlayDidChange)
            .receive(on: RunLoop.main)) { _ in
            plays = store.plays(for: session)
        }
    }

    private var durationText: String {
        let minutes = Int(session.duration / 60.0)
        return String(localized: "Sessions.Duration.\(minutes)")
    }
}
