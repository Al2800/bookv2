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
        .tint(.brand)
        .toolbarBackground(Color.card.opacity(0.98), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .background(Color.paper.ignoresSafeArea())
    }
}

#Preview {
    RootView()
        .environment(AppStore())
}
