import SwiftUI

struct JoystickVisual: View {

    let x: CGFloat
    let y: CGFloat

    var body: some View {

        ZStack {

            Circle()
                .fill(
                    Color(
                        white: 0.08,
                        opacity: 0.35
                    )
                )
                .frame(
                    width: 144,
                    height: 144
                )

            Circle()
                .fill(
                    Color(
                        white: 0.9,
                        opacity: 0.45
                    )
                )
                .frame(
                    width: 64,
                    height: 64
                )
                .offset(
                    x: x,
                    y: y
                )
        }
        .frame(
            width: 144,
            height: 144
        )
    }
}