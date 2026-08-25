import SwiftUI

struct EmptyStateView: View {

    let symbol: String
    let title: String
    let message: String

    var body: some View {

        VStack(spacing: 10) {

            Image(systemName: symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)

            Text(title)
                .font(
                    .system(
                        size: 20,
                        weight: .semibold
                    )
                )

            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(
                    BSTheme.secondaryText
                )
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }
}