import SwiftUI

struct ExitVisual: View {

    var body: some View {

        GeometryReader { geometry in

            let top =
                max(
                    geometry.safeAreaInsets.top,
                    12.0
                )

            Text("Exit")
                .font(
                    .system(
                        size: 16,
                        weight: .regular
                    )
                )
                .foregroundStyle(.white)
                .frame(
                    width: 92,
                    height: 38
                )
                .background(
                    Color(
                        white: 0.05,
                        opacity: 0.60
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 9
                    )
                )
                .position(
                    x: 62,
                    y: top + 19
                )
        }
    }
}