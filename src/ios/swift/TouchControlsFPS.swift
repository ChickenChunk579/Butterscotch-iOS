import SwiftUI

struct FPSVisual: View {

    let fps: Double

    var body: some View {
        Text(String(format: "%.0f FPS", fps))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(width: 110)
            .background(.ultraThinMaterial)
            .clipShape(
                RoundedRectangle(cornerRadius: 12)
            )
    }
}
