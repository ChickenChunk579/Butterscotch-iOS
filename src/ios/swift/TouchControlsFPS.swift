import SwiftUI

struct FPSVisual: View {

    let fps: Double

    var body: some View {

        Text(
            String(
                format: "FPS: %.0f",
                fps
            )
        )
        .font(
            .system(
                size: 16,
                weight: .bold
            )
        )
        .foregroundStyle(.white)
        .frame(
            width: 90,
            height: 32
        )
        .background(
            Color(
                white: 0.05,
                opacity: 0.60
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 8
            )
        )
    }
}