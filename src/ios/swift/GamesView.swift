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
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(
                            minimum: 180,
                            maximum: 320
                        ),
                        spacing: 18
                    )
                ],
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
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
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

    private let steamGridDB: SteamGridDB

    @State private var heroURL: URL?
    @State private var isPressed = false

    init(game: Game) {
        self.game = game
        self.steamGridDB = SteamGridDB(
            apiKey: "54d085cdf879d930050b2e43558e9841"
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

                // SteamGridDB artwork
                ZStack {
                    // Glow
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.accentColor)
                        .blur(radius: 14)
                        .opacity(0.7)

                    // Artwork
                    Group {
                        if let heroURL {
                            AsyncImage(url: heroURL) { phase in
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
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 14
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 14
                )
                .stroke(
                    .white.opacity(
                        isPressed ? 0.25 : 0
                    ),
                    lineWidth: 1
                )
            }
            .shadow(
                color: .black.opacity(0.18),
                radius: 8,
                y: 5
            )

            Text(game.name)
                .font(.headline)
                .lineLimit(1)

            Text(game.description)
                .font(.caption)
                .foregroundStyle(.secondary)
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
                heroURL = try await steamGridDB.gridURL(
                    forSteamAppID: Int(game.steamAppID)
                )
            } catch {
                print(
                    "Failed to load SteamGridDB artwork:",
                    error
                )
            }
        }
    }
}


// MARK: - Game Detail View

struct GameDetailView: View {
    let game: Game
    let onPlay: () -> Void

    private let steamGridDB: SteamGridDB

    @State private var heroURL: URL?
    @State private var logoURL: URL?

    init(game: Game, onPlay: @escaping () -> Void) {
        self.game = game
        self.onPlay = onPlay
        self.steamGridDB = SteamGridDB(apiKey:"54d085cdf879d930050b2e43558e9841")
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

            // Hero artwork
            Group {
                if let heroURL {
                    AsyncImage(url: heroURL) { phase in
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(
                RoundedRectangle(cornerRadius: 22)
            )

            // Title
            Group {
                if let logoURL {
                    AsyncImage(url: logoURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()

                        case .failure, .empty:
                            Text(game.name)
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)

                        @unknown default:
                            Text(game.name)
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text(game.name)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .task {
            do {
                heroURL = try await steamGridDB.heroURL(
                    forSteamAppID: Int(game.steamAppID)
                )

                logoURL = try await steamGridDB.logoURL(
                    forSteamAppID: Int(game.steamAppID)
                )
            } catch {
                print("Failed to load SteamGridDB artwork:", error)
            }
        }
        .frame(
            maxWidth: .infinity
        )
        .frame(height: 360)
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

    private var about: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Button(action: onPlay) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("Play")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: 128)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(BSTheme.accent)
                }
                .shadow(
                    color: BSTheme.accent.opacity(0.3),
                    radius: 10,
                    y: 5
                )
            }
            .buttonStyle(.plain)

            Text("About")
                .font(.title2)
                .fontWeight(.bold)

            Text(
                game.description
            )
            .font(.body)
            .foregroundStyle(.secondary)
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
