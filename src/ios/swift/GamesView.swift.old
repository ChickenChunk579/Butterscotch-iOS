import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct GamesView: View {

    @ObservedObject
    var store = GameStore.shared

    @State var editingGame: Game?
    @State var showingEditor = false
    @State var isExportingSaves = false
    @State var errorMessage: String?
    @State var successMessage: String?

    enum ImportMode {
        case game
        case saves
    }

    @State var importMode: ImportMode?
    @State var isPresentingImporter = false
    @State var backupDocument: SaveBackupDocument?
    @State var targetGame: Game?


    var body: some View {
        NavigationStack {
            Group {
                if store.games.isEmpty {
                    EmptyStateView(
                        symbol: "plus.rectangle.on.folder",
                        title: "Your Library Is Empty",
                        message:
                            "Tap + to import a GameMaker ZIP containing a data.win."
                    )
                } else {
                    gameLibrary
                }
            }
            .navigationTitle("Games")
            .toolbar {
                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    Button {
                        importMode = .game
                        isPresentingImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Import Game")
                }
            }
            .fileImporter(
                isPresented: $isPresentingImporter,
                allowedContentTypes: {
                    switch importMode {
                    case .game:
                        return [UTType.zip]

                    case .saves:
                        return [UTType.folder]

                    case nil:
                        return []
                    }
                }(),
                allowsMultipleSelection: false
            ) { result in

                let mode = importMode
                importMode = nil

                switch mode {
                case .game:
                    handleImport(result)

                case .saves:
                    handleSaveFolderImport(result)

                case nil:
                    break
                }
            }
            .fileExporter(
                isPresented: $isExportingSaves,
                document: backupDocument,
                contentType: .zip,
                defaultFilename:
                    "\(targetGame?.name ?? "Game")_Saves.zip"
            ) { result in

                if case .failure(let error) = result {
                    print(
                        "Export error: \(error.localizedDescription)"
                    )
                }

                targetGame = nil
            }
            .sheet(
                isPresented: $showingEditor,
                onDismiss: {
                    editingGame = nil
                }
            ) {
                if let editingGame {
                    GameEditorView(
                        game: editingGame
                    )
                }
            }
            .alert(
                "Saves Imported",
                isPresented: Binding(
                    get: {
                        successMessage != nil
                    },
                    set: {
                        if !$0 {
                            successMessage = nil
                        }
                    }
                )
            ) {
                Button("OK") {
                    successMessage = nil
                }
            } message: {
                Text(successMessage ?? "")
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: {
                        errorMessage != nil
                    },
                    set: {
                        if !$0 {
                            errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Game Library

    private var gameLibrary: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            // Adjust these breakpoints to your liking
            let columnCount: Int = {
                if width < 700 {
                    return 2
                } else {
                    return 4
                }
            }()

            let spacing: CGFloat = 12
            let horizontalPadding: CGFloat = 16

            let availableWidth =
                width
                - (horizontalPadding * 2)
                - (spacing * CGFloat(columnCount - 1))

            let cardWidth = availableWidth / CGFloat(columnCount)

            ScrollView {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(
                            .fixed(cardWidth),
                            spacing: spacing
                        ),
                        count: columnCount
                    ),
                    spacing: 24
                ) {
                    ForEach(store.games) { game in
                        NavigationLink {
                            GameDetailView(
                                game: game,
                                onPlay: {
                                    play(game)
                                }
                            )
                        } label: {
                            GameCard(game: game)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            gameContextMenu(for: game)
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func gameContextMenu(
        for game: Game
    ) -> some View {

        Button {
            editingGame = game
            showingEditor = true
        } label: {
            Label(
                "Edit",
                systemImage: "pencil"
            )
        }

        Button {
            targetGame = game

            backupDocument =
                GameStore.shared.prepareBackupDocument(
                    for: game
                )

            isExportingSaves = true
        } label: {
            Label(
                "Backup Saves",
                systemImage: "archivebox"
            )
        }

        Button {
            targetGame = game
            importMode = .saves
            isPresentingImporter = true
        } label: {
            Label(
                "Import Saves",
                systemImage: "arrow.down.doc"
            )
        }

        Divider()

        Button(
            role: .destructive
        ) {
            store.delete(game)
        } label: {
            Label(
                "Delete",
                systemImage: "trash"
            )
        }
    }
}


// MARK: - Game Card

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

                // Background
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

                // Box art
                ZStack {
                    // Artwork
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
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )


                // Dark gradient so the title is readable
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
                6/9,
                contentMode: .fit
            )
            .compositingGroup()
            .shadow(
                color: BSTheme.accent.opacity(0.85),
                radius: 12,
                x: 0,
                y: 0
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
        .scaleEffect(
            isPressed ? 0.97 : 1
        )
        .animation(
            .easeOut(duration: 0.12),
            value: isPressed
        )
        .task {
            do {
                boxartURL = try await artProvider.gridURL(for: game)
            } catch {
                print(
                    "Failed to load game artwork:",
                    error
                )
            }
        }
    }
}


// MARK: - Game Detail View

struct GameDetailView: View {
    @State var game: Game
    let onPlay: () -> Void

    let artProvider: GameArtProvider

    @State private var heroURL: URL?
    @State private var logoURL: URL?

    init(game: Game, onPlay: @escaping () -> Void) {
        self.game = game
        self.onPlay = onPlay
        self.artProvider = GameArtProvider(steamGridDBAPIKey: "54d085cdf879d930050b2e43558e9841")
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
                                RoundedRectangle(cornerRadius: 22)
                            )

                    case .failure:
                        fallbackIcon
                            .frame(maxWidth: .infinity)
                            .frame(height: 250)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(
                                RoundedRectangle(cornerRadius: 22)
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
                heroURL = try await artProvider.heroURL(for: game)
                logoURL = try await artProvider.logoURL(for: game)
            } catch {
                print("Failed to load game artwork:", error)
            }
        }
        .frame(
            maxWidth: .infinity
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22
            )
        )
        .shadow(
            color: .black.opacity(0.2),
            radius: 15,
            y: 8
        )
        .padding(.top, 8)
    }

    // MARK: - About
    
    private var playButton: some View {
        Button(action: {
            let startTime = Date.now
            onPlay()
            game.lastPlayed = Date.now
            
            let range = Duration.seconds(game.lastPlayed.timeIntervalSince(startTime))
            
            game.playTime += range
            
            GameStore.shared.update(game)
        }) {
            HStack(spacing: 9) {
                Image(systemName: "play.fill")
                    .font(.system(size: 20, weight: .bold))

                Text("Play")
                    .font(.system(size: 20, weight: .bold))
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
                color: BSTheme.accent.opacity(0.25),
                radius: 10,
                y: 5
            )
        }
        .buttonStyle(.plain)
    }
    
    private var gameInformation: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Game Information",
                icon: "info.circle"
            )

            // Add alignment: .leading here
            VStack(alignment: .leading, spacing: 9) {
                infoRow(title: "Developers", value: game.developers)
                infoRow(title: "Publisher", value: game.publisher)
                infoRow(title: "Release Date", value: getRelativeDateString(from: game.releaseDate))
                infoRow(title: "Genres", value: game.genres)
                infoRow(title: "Platforms", value: game.platforms)
            }
        }
    }

    
    private var categories: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Categories",
                icon: "square.grid.2x2"
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    categoryTag("Single-player")
                    categoryTag("Multiplayer")
                }

                categoryTag("Steam Achievements")
            }
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 20) {

            // MARK: - Play + Stats

            ViewThatFits(in: .horizontal) {
                // Desktop
                HStack(spacing: 14) {
                    playButton
                        .frame(width: 256)

                    statCard(
                        title: "Play time",
                        value: game.playTime.formatted(
                            .units(allowed: [.hours, .minutes], width: .narrow)
                        ),
                        icon: "clock.fill"
                    )

                    statCard(
                        title: "Last Played",
                        value: getRelativeDateString(from: game.lastPlayed),
                        icon: "calendar"
                    )
                }

                // Smaller screens
                VStack(spacing: 12) {
                    playButton
                        .frame(height: 56)

                    HStack(spacing: 12) {
                        statCard(
                            title: "Play time",
                            value: game.playTime.formatted(
                                .units(allowed: [.hours, .minutes], width: .narrow)
                            ),
                            icon: "clock.fill"
                        )

                        statCard(
                            title: "Last Played",
                            value: getRelativeDateString(from: game.lastPlayed),
                            icon: "calendar"
                        )
                    }
                }
            }

            // MARK: - About

            VStack(alignment: .leading, spacing: 8) {
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

            // MARK: - Information + Categories

            ViewThatFits(in: .horizontal) {
                // iPad / wider layouts
                HStack(alignment: .top, spacing: 20) {
                    gameInformation
                        .frame(maxWidth: .infinity, alignment: .leading)

                    categories
                        .frame(width: 220, alignment: .leading)
                }

                // iPhone / narrower layouts
                VStack(alignment: .leading, spacing: 20) {
                    gameInformation
                        .frame(maxWidth: .infinity, alignment: .leading)

                    categories
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(18)
            .background {
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .fill(.quaternary.opacity(0.35))
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(
        title: String,
        icon: String
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BSTheme.accent)

            Text(title)
                .font(.headline)
                .fontWeight(.bold)
        }
    }

    // MARK: - Section Background

    private var sectionBackground: some View {
        RoundedRectangle(
            cornerRadius: 20,
            style: .continuous
        )
        .fill(.quaternary.opacity(0.45))
        .overlay {
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                .primary.opacity(0.06),
                lineWidth: 1
            )
        }
    }
    private func infoRow(
        title: String,
        value: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

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
                .foregroundStyle(BSTheme.accent)

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .fill(Color.primary.opacity(0.05))
        }
    }

    private func categoryTag(
        _ title: String
    ) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                Capsule()
                    .fill(Color.primary.opacity(0.06))
            }
    }
}


// MARK: - Detail Row

struct GameDetailRow: View {

    let title: String
    let value: String

    var body: some View {
        HStack {

            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 12)
    }
}
