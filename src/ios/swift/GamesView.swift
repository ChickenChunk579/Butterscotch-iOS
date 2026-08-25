import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct GamesView: View {

    @ObservedObject
    private var store = GameStore.shared

    @State private var showingImporter = false
    @State private var editingGame: Game?
    @State private var showingEditor = false
    @State private var errorMessage: String?

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
                        showingImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [
                    .zip
                ],
                allowsMultipleSelection: false
            ) { result in

                handleImport(result)
            }
            .sheet(
                isPresented: $showingEditor
            ) {

                if let editingGame {

                    GameEditorView(
                        game: editingGame
                    )
                }
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
}
