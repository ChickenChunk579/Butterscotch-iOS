import SwiftUI

struct GameRow: View {

    let game: Game

    @ObservedObject
    private var store = GameStore.shared

    var body: some View {

        HStack(spacing: 12) {

            Group {

                if let image = store.icon(for: game) {

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()

                } else {

                    Text(
                        game.name
                            .first
                            .map(String.init)?
                            .uppercased()
                            ?? "?"
                    )
                    .font(
                        .system(
                            size: 20,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(BSTheme.accent)
                }
            }
            .frame(width: 44, height: 44)
            .background(
                BSTheme.accent.opacity(0.16)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
            )

            VStack(alignment: .leading, spacing: 2) {

                Text(game.name)
                    .font(
                        .system(
                            size: 17,
                            weight: .semibold
                        )
                    )

                Text(
                    game.description.isEmpty
                        ? "Tap to play"
                        : game.description
                )
                .font(.system(size: 13))
                .foregroundStyle(
                    BSTheme.secondaryText
                )
                .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(
                    .system(
                        size: 13,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
    }
}