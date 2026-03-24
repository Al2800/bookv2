import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }

            CaptureHomeView()
                .tabItem {
                    Label("Capture", systemImage: "viewfinder")
                }
        }
        .tint(.ink)
        .toolbarBackground(Color.paper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

#Preview {
    RootView()
        .environment(AppStore())
}
