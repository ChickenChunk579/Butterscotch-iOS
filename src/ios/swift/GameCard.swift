import SwiftUI

struct GameCard: View {

    let game: Game
    let artProvider: GameArtProvider

    @State private var boxartURL: URL?
    @State private var isPressed = false

    init(game: Game) {
        self.game = game
        self.artProvider = GameArtProvider(
            steamGridDBAPIKey: "54d085cdf879d930050b2e43558e9841"
        )
    }

    private var fallbackIcon: some View {
        Image(systemName: "gamecontroller.fill")
            .font(.system(size: 44))
            .foregroundStyle(.white.opacity(0.75))
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            ZStack(alignment: .bottomLeading) {

                RoundedRectangle(
                    cornerRadius: 14
                )
                .fill(
                    LinearGradient(
                        colors: [
                            BSTheme.accent.opacity(0.75),
                            Color.black.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                Group {
                    if let boxartURL {
                        CachedAsyncImage(url: boxartURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()

                            case .failure, .empty:
                                fallbackIcon

                            @unknown default:
                                fallbackIcon
                            }
                        }
                    } else {
                        fallbackIcon
                    }
                }
                .clipShape(
                    RoundedRectangle(cornerRadius: 14)
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )

                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.85)
                    ],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 14
                    )
                )
            }
            .aspectRatio(
                6 / 9,
                contentMode: .fit
            )
            .compositingGroup()
            .shadow(
                color: BSTheme.accent.opacity(0.85),
                radius: 12
            )
            .shadow(
                color: .black.opacity(0.18),
                radius: 8,
                y: 5
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        .white.opacity(isPressed ? 0.25 : 0),
                        lineWidth: 1
                    )
            }

            Text(game.name)
                .font(.headline)
                .lineLimit(1)

            Text(game.developers)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .scaleEffect(isPressed ? 0.97 : 1)
        .animation(
            .easeOut(duration: 0.12),
            value: isPressed
        )
        .task {
            do {
                boxartURL =
                    try await artProvider.gridURL(
                        for: game
                    )
            } catch {
                print(
                    "Failed to load game artwork:",
                    error
                )
            }
        }
    }
}