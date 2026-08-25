import SwiftUI

struct LauncherView: View {
    
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {

            
            GamesView()
                .tabItem {
                    Label(
                        "Games",
                        systemImage: "play.fill"
                    )
                }
                .tag(0)
            
            SettingsView()
                .tabItem {
                    Label(
                        "Settings",
                        systemImage: "gearshape"
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
