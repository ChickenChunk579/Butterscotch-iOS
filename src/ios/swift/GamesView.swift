import SwiftUI
import UniformTypeIdentifiers

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

            let cardWidth =
                availableWidth / CGFloat(columnCount)

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