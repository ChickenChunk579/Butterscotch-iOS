import SwiftUI

struct LauncherView: View {
    
    @State private var selectedTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            SettingsView()
                .tabItem {
                    Label(
                        "Settings",
                        systemImage: "gearshape"
                    )
                }
                .tag(0)

            GamesView()
                .tabItem {
                    Label(
                        "Library",
                        systemImage: "books.vertical.fill"
                    )
                }
                .tag(1)
            
            AboutView()
                .tabItem {
                    Label(
                        "About",
                        systemImage: "info.circle"
                    )
                }
        }
        .tint(BSTheme.accent)
    }
}
