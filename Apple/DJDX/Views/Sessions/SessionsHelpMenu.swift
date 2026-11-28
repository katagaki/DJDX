import SwiftUI

struct SessionsHelpMenu: View {
    var body: some View {
        Menu {
            Text("Sessions.Welcome.Message")
        } label: {
            Label("Sessions.Help", systemImage: "questionmark.circle")
        }
        .menuOrder(.fixed)
    }
}
