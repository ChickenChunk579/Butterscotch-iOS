import SwiftUI

struct GameDetailView: View {

    @State var game: Game

    let onPlay: () -> Void
    let artProvider: GameArtProvider

    @State private var heroURL: URL?
    @State private var logoURL: URL?

    init(
        game: Game,
        onPlay: @escaping () -> Void
    ) {
        self.game = game
        self.onPlay = onPlay

        self.artProvider = GameArtProvider(
            steamGridDBAPIKey:
                "54d085cdf879d930050b2e43558e9841"
        )

        self._heroURL = State(initialValue: nil)
    }

    private var fallbackIcon: some View {
        Image(systemName: "gamecontroller.fill")
            .font(.system(size: 110))
            .foregroundStyle(.white.opacity(0.12))
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
    }

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 28
            ) {
                hero
                about
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background {
            Color(
                uiColor:
                    .systemGroupedBackground
            )
            .ignoresSafeArea()
        }
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {

            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            BSTheme.accent.opacity(0.7),
                            Color.black.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let heroURL {
                CachedAsyncImage(url: heroURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 22
                                )
                            )

                    case .failure:
                        fallbackIcon
                            .frame(maxWidth: .infinity)
                            .frame(height: 250)
                            .background(
                                Color.gray.opacity(0.1)
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 22
                                )
                            )

                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 250)

                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .task {
            do {
                heroURL =
                    try await artProvider.heroURL(
                        for: game
                    )

                logoURL =
                    try await artProvider.logoURL(
                        for: game
                    )
            } catch {
                print(
                    "Failed to load game artwork:",
                    error
                )
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
        .shadow(
            color: .black.opacity(0.2),
            radius: 15,
            y: 8
        )
        .padding(.top, 8)
    }

    // MARK: - Play

    private var playButton: some View {
        Button {
            let startTime = Date.now

            onPlay()

            game.lastPlayed = Date.now

            let range =
                Duration.seconds(
                    game.lastPlayed
                        .timeIntervalSince(startTime)
                )

            game.playTime += range

            GameStore.shared.update(game)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "play.fill")
                    .font(
                        .system(
                            size: 20,
                            weight: .bold
                        )
                    )

                Text("Play")
                    .font(
                        .system(
                            size: 20,
                            weight: .bold
                        )
                    )
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .fill(BSTheme.accent)
            }
            .shadow(
                color:
                    BSTheme.accent.opacity(0.25),
                radius: 10,
                y: 5
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Information

    private var gameInformation: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            sectionHeader(
                title: "Game Information",
                icon: "info.circle"
            )

            VStack(
                alignment: .leading,
                spacing: 9
            ) {
                infoRow(
                    title: "Developers",
                    value: game.developers
                )

                infoRow(
                    title: "Publisher",
                    value: game.publisher
                )

                infoRow(
                    title: "Release Date",
                    value: getRelativeDateString(
                        from: game.releaseDate
                    )
                )

                infoRow(
                    title: "Genres",
                    value: game.genres
                )

                infoRow(
                    title: "Platforms",
                    value: game.platforms
                )
            }
        }
    }

    // MARK: - Categories

    private var categories: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            sectionHeader(
                title: "Categories",
                icon: "square.grid.2x2"
            )

            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                HStack(spacing: 8) {
                    categoryTag("Single-player")
                    categoryTag("Multiplayer")
                }

                categoryTag("Steam Achievements")
            }
        }
    }

    // MARK: - About

    private var about: some View {
        VStack(
            alignment: .leading,
            spacing: 20
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    playButton
                        .frame(width: 256)

                    statCard(
                        title: "Play time",
                        value: game.playTime.formatted(
                            .units(
                                allowed: [
                                    .hours,
                                    .minutes
                                ],
                                width: .narrow
                            )
                        ),
                        icon: "clock.fill"
                    )

                    statCard(
                        title: "Last Played",
                        value:
                            getRelativeDateString(
                                from: game.lastPlayed
                            ),
                        icon: "calendar"
                    )
                }

                VStack(spacing: 12) {
                    playButton
                        .frame(height: 56)

                    HStack(spacing: 12) {
                        statCard(
                            title: "Play time",
                            value:
                                game.playTime.formatted(
                                    .units(
                                        allowed: [
                                            .hours,
                                            .minutes
                                        ],
                                        width: .narrow
                                    )
                                ),
                            icon: "clock.fill"
                        )

                        statCard(
                            title: "Last Played",
                            value:
                                getRelativeDateString(
                                    from: game.lastPlayed
                                ),
                            icon: "calendar"
                        )
                    }
                }
            }

            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                sectionHeader(
                    title: "About",
                    icon: "text.alignleft"
                )

                Text(game.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .lineLimit(4)
            }

            ViewThatFits(in: .horizontal) {
                HStack(
                    alignment: .top,
                    spacing: 20
                ) {
                    gameInformation
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )

                    categories
                        .frame(
                            width: 220,
                            alignment: .leading
                        )
                }

                VStack(
                    alignment: .leading,
                    spacing: 20
                ) {
                    gameInformation
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )

                    categories
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                }
            }
            .padding(18)
            .background {
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .fill(
                    .quaternary.opacity(0.35)
                )
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(
        title: String,
        icon: String
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(
                    .system(
                        size: 13,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    BSTheme.accent
                )

            Text(title)
                .font(.headline)
                .fontWeight(.bold)
        }
    }

    private func infoRow(
        title: String,
        value: String
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: 12
        ) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(
                    width: 110,
                    alignment: .leading
                )

            Text(value)
                .fontWeight(.medium)
        }
    }

    private func statCard(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(
                    BSTheme.accent
                )

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(14)
        .background {
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .fill(
                Color.primary.opacity(0.05)
            )
        }
    }

    private func categoryTag(
        _ title: String
    ) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(
                .horizontal,
                10
            )
            .padding(
                .vertical,
                7
            )
            .background {
                Capsule()
                    .fill(
                        Color.primary.opacity(0.06)
                    )
            }
    }
}