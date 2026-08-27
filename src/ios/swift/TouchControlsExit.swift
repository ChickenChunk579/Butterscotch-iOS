import SwiftUI

struct ExitVisual: View {

    var body: some View {
        Button {
            // Exit action
        } label: {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial)
                .clipShape(
                    RoundedRectangle(cornerRadius: 10)
                )
        }
        .buttonStyle(.plain)
        .padding(.leading, 16)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
