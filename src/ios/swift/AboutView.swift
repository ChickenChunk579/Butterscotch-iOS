import SwiftUI

struct AboutView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image("icon")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)

            Text("Butterscotch iOS")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("commit \(BuildInfo.commitHash)")
                .font(.footnote)
                .fontWeight(.light)

            Divider()

            
            Text("A fork of Butterscotch runner, an open source re-implementation of GameMaker: Studio's runner (YoYo Runner), adding iOS support")

            HStack {
                Link("GitHub", destination: URL(string: "https://github.com/ChickenChunk579/Butterscotch-iOS")!)
                
                Link("Upstream", destination: URL(string: "https://github.com/ButterscotchRunner/Butterscotch")!)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}
