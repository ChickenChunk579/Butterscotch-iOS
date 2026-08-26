import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct GamesView: View {

    @ObservedObject
    private var store = GameStore.shared

    @State private var editingGame: Game?
    @State private var showingEditor = false
    @State private var isExportingSaves = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private enum ImportMode {
        case game
        case saves
    }

    @State private var importMode: ImportMode?
    @State private var isPresentingImporter = false
    @State private var backupDocument: SaveBackupDocument?
    @State private var targetGame: Game?

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
                                        backupDocument = GameStore.shared.prepareBackupDocument(for: game)
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
                defaultFilename: "\(targetGame?.name ?? "Game")_Saves.zip"
            ) { result in
                if case .failure(let error) = result {
                    print("Export error: \(error.localizedDescription)")
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

    // MARK: - Import

    private func handleImport(
        _ result: Result<[URL], Error>
    ) {

        switch result {

        case .failure(let error):

            errorMessage = error.localizedDescription

        case .success(let urls):

            guard let url = urls.first else {
                return
            }

            importZIP(url)
        }
    }

    private func importZIP(_ source: URL) {

        let scoped =
            source.startAccessingSecurityScopedResource()

        let identifier =
            UUID().uuidString

        let directory =
            store.gamesDirectory
                .appendingPathComponent(
                    identifier,
                    isDirectory: true
                )

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        DispatchQueue.global(
            qos: .userInitiated
        ).async {

            var dataWin =
                [CChar](
                    repeating: 0,
                    count: 4096
                )

            var error =
                [CChar](
                    repeating: 0,
                    count: 512
                )

            let extracted =
                IOSZipImport_extract(
                    source.path,
                    directory.path,
                    &dataWin,
                    dataWin.count,
                    &error,
                    error.count
                )

            if scoped {
                source.stopAccessingSecurityScopedResource()
            }

            let dataWinPath =
                String(
                    cString: dataWin
                )

            let errorMessage =
                String(
                    cString: error
                )

            DispatchQueue.main.async {

                guard extracted else {

                    try? FileManager.default
                        .removeItem(
                            at: directory
                        )

                    if errorMessage.isEmpty {

                        self.setError(
                            "Could not import this ZIP."
                        )

                    } else {

                        self.setError(
                            errorMessage
                        )
                    }

                    return
                }

                guard FileManager.default.fileExists(
                    atPath: dataWinPath
                ) else {

                    try? FileManager.default
                        .removeItem(
                            at: directory
                        )

                    self.setError(
                        "The ZIP importer did not produce a readable data.win."
                    )

                    return
                }

                let saveDirectory =
                    directory
                        .appendingPathComponent(
                            "Saves",
                            isDirectory: true
                        )

                try? FileManager.default
                    .createDirectory(
                        at: saveDirectory,
                        withIntermediateDirectories: true
                    )

                let gamesPath =
                    store.gamesDirectory.path

                let dataWinRel: String

                if dataWinPath.hasPrefix(
                    gamesPath
                ) {

                    dataWinRel = String(
                        dataWinPath.dropFirst(
                            gamesPath.count + 1
                        )
                    )

                } else {

                    dataWinRel = dataWinPath
                }

                let game =
                    Game(
                        id: identifier,
                        name:
                            source
                                .deletingPathExtension()
                                .lastPathComponent,
                        description: "",
                        dataWinRel: dataWinRel,
                        dirRel: identifier,
                        saveDirRel:
                            "\(identifier)/Saves",
                        iconRel: nil
                    )

                store.add(game)

                // Open the metadata editor immediately after a
                // successful import so the user can name/describe
                // the game and (if the editor supports it) pick
                // an icon before it shows up in the library.
                editingGame = game
                showingEditor = true
            }
        }
    }

    // MARK: - Play

    private func play(_ game: Game) {

        guard FileManager.default.fileExists(
            atPath: gameDataPath(game)
        ) else {

            errorMessage =
                "This game's data.win is missing. Delete this entry and import the ZIP again."

            return
        }

        let defaults =
            UserDefaults.standard

        var settings =
            IOSLaunchSettings()

        settings.lazyRooms =
            defaults.bool(
                forKey: "ios.lazyRooms"
            )

        settings.lazyTextures =
            defaults.bool(
                forKey: "ios.lazyTextures"
            )

        settings.lazyAudio =
            defaults.bool(
                forKey: "ios.lazyAudio"
            )

        settings.touchControls =
            defaults.bool(
                forKey: "ios.touchControls"
            )

        settings.showFPS =
            defaults.bool(
                forKey: "ios.showFPS"
            )

        settings.speedMultiplier =
            defaults.double(
                forKey: "ios.speed"
            )

        settings.widescreenAspect =
            defaults.bool(
                forKey: "ios.widescreen"
            )
            ? Float(16.0 / 9.0)
            : 0.0

        store.selectedGameID =
            game.id

        let dataWin =
            store.dataWinURL(
                for: game
            ).path

        let saveDir =
            store.saveDirectoryURL(
                for: game
            ).path

        IOSLauncher_startGame(
            dataWin,
            saveDir,
            &settings,
            nil
        )
    }

    private func gameDataPath(
        _ game: Game
    ) -> String {

        store.dataWinURL(
            for: game
        ).path
    }

    // MARK: - Error

    private func setError(
        _ message: String
    ) {
        errorMessage = message
    }

    private func handleSaveFolderImport(
        _ result: Result<[URL], Error>
    ) {

        guard let game = targetGame else {
            return
        }

        defer {
            targetGame = nil
        }

        switch result {

        case .success(let urls):

            guard let selectedURL = urls.first else {
                return
            }

            let success =
                store.importSaveFolder(
                    from: selectedURL,
                    for: game
                )

            if success {
                successMessage =
                    "Your save files were imported successfully."
            } else {
                errorMessage =
                    "Could not import the selected save folder."
            }

        case .failure(let error):

            errorMessage =
                "Save import failed: \(error.localizedDescription)"
        }
    }
}