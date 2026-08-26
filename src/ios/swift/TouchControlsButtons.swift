import SwiftUI

struct ActionButtonsVisual: View {

    let zHeld: Bool
    let xHeld: Bool
    let cHeld: Bool

    var body: some View {

        GeometryReader { geometry in

            let bottom =
                max(
                    geometry.safeAreaInsets.bottom,
                    20.0
                )

            ZStack {

                ActionButtonVisual(
                    title: "Z",
                    held: zHeld
                )
                .position(
                    x: geometry.size.width - 82,
                    y: geometry.size.height - bottom - 78
                )

                ActionButtonVisual(
                    title: "X",
                    held: xHeld
                )
                .position(
                    x: geometry.size.width - 152,
                    y: geometry.size.height - bottom - 44
                )

                ActionButtonVisual(
                    title: "C",
                    held: cHeld
                )
                .position(
                    x: geometry.size.width - 82,
                    y: geometry.size.height - bottom - 148
                )
            }
        }
    }
}


struct ActionButtonVisual: View {

    let title: String
    let held: Bool

    var body: some View {

        ZStack {

            Circle()
                .fill(
                    Color(
                        white:
                            held
                                ? 0.85
                                : 0.15,
                        opacity:
                            held
                                ? 0.70
                                : 0.45
                    )
                )

            Text(title)
                .font(
                    .system(
                        size: 23,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)
        }
        .frame(
            width: 68,
            height: 68
        )
    }
}