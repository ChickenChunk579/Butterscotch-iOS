import SwiftUI

struct AboutView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image("icon")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)

            Text("Butterscotch Runner")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("commit \(BuildInfo.commitHash)")
                .font(.footnote)
                .fontWeight(.light)

            Divider()

            
            Text("An open source re-implementation of GameMaker: Studio's runner (YoYo Runner)")

            HStack {
                Link("GitHub", destination: URL(string: "https://github.com/...")!)
                
                //Link("Website", destination: URL(string: "https://...")!)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}