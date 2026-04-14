import SwiftUI

struct ToolsHubView: View {
    var body: some View {
        List {
            Section("Tools") {
                NavigationLink(destination: TranslateView()) {
                    Label(String(localized: "Translate"), systemImage: "character.book.closed")
                }
                NavigationLink(destination: TopicGridView()) {
                    Label(String(localized: "Browse Topics"), systemImage: "square.grid.2x2")
                }
                NavigationLink(destination: DiscoverView()) {
                    Label(String(localized: "Discover"), systemImage: "sparkles")
                }
            }
        }
        .navigationTitle("Tools")
    }
}
