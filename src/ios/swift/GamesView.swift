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
                    List {
                        ForEach(store.games) { game in
                            GameRow(game: game)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    play(game)
                                }
                                .swipeActions(
                                    edge: .trailing,
                                    allowsFullSwipe: false
                                ) {
                                    Button("Delete", role: .destructive) {
                                        store.delete(game)
                                    }

                                    Button("Edit") {
                                        editingGame = game
                                        showingEditor = true
                                    }
                                    .tint(BSTheme.accent)

                                    Button("Backup Saves") {
                                        targetGame = game
                                        backupDocument =
                                            GameStore.shared.prepareBackupDocument(
                                                for: game
                                            )
                                        isExportingSaves = true
                                    }

                                    Button("Import Saves") {
                                        targetGame = game
                                        importMode = .saves
                                        isPresentingImporter = true
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
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
}