import Foundation
import UniformTypeIdentifiers

extension GamesView {

    // MARK: - Import

    func handleImport(
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

    func importZIP(_ source: URL) {

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

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            performZIPExtraction(
                source: source,
                directory: directory,
                identifier: identifier,
                scoped: scoped
            )
        }
    }

    // MARK: - Extraction (background)

    /// Runs on a background queue. Pulled out into its own method (with an
    /// explicit signature) so the compiler type-checks it independently of
    /// the `.async` call — otherwise a type error inside a large trailing
    /// closure can get misreported as "Trailing closure passed to parameter
    /// of type 'DispatchWorkItem'".
    private func performZIPExtraction(
        source: URL,
        directory: URL,
        identifier: String,
        scoped: Bool
    ) {

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

        DispatchQueue.main.async { [self] in
            finishZIPExtraction(
                extracted: extracted,
                dataWinPath: dataWinPath,
                errorMessage: errorMessage,
                source: source,
                directory: directory,
                identifier: identifier
            )
        }
    }

    // MARK: - Extraction (main thread completion)

    private func finishZIPExtraction(
        extracted: Bool,
        dataWinPath: String,
        errorMessage: String,
        source: URL,
        directory: URL,
        identifier: String
    ) {

        guard extracted else {

            try? FileManager.default
                .removeItem(
                    at: directory
                )

            if errorMessage.isEmpty {
                setError(
                    "Could not import this ZIP."
                )
            } else {
                setError(
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

            setError(
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
                developers: "",
                publisher: "",
                description: "",
                genres: "",
                platforms: "",
                categories: [],
                steamAppID: "",
                fetchFromSteam: true,
                dataWinRel: dataWinRel,
                dirRel: identifier,
                saveDirRel:
                    "\(identifier)/Saves",
                playTime: .seconds(0),
                lastPlayed: Date.now,
                iconRel: nil
            )

        store.add(game)

        editingGame = game
        showingEditor = true
    }

    // MARK: - Save folder import

    func handleSaveFolderImport(
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
