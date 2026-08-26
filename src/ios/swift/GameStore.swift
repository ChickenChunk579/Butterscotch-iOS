import Foundation
import UIKit

struct Game: Identifiable, Codable, Equatable {

    let id: String

    var name: String
    var description: String

    var dataWinRel: String
    var dirRel: String
    var saveDirRel: String

    var iconRel: String?
}

struct Mod: Identifiable, Codable, Equatable {

    let id: String

    var name: String

    /// Path relative to the application's Mods directory.
    var fileRel: String
}

final class GameStore: ObservableObject {

    static let shared = GameStore()

    @Published private(set) var games: [Game] = []
    @Published private(set) var mods: [Mod] = []

    private let gamesKey = "ios.games"
    private let modsKey = "ios.mods"

    private let selectedGameKey =
        "ios.selectedGame"

    private init() {
        load()
    }

    // MARK: Defaults

    static func registerDefaults() {

        UserDefaults.standard.register(
            defaults: [
                "ios.lazyRooms": true,
                "ios.lazyTextures": true,
                "ios.lazyAudio": true,
                "ios.touchControls": true,
                "ios.speed": 1.0,
                "ios.widescreen": false
            ]
        )
    }

    // MARK: Storage

    private var applicationSupportDirectory: URL {

        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
    }

    var gamesDirectory: URL {

        let directory =
            applicationSupportDirectory
                .appendingPathComponent(
                    "Butterscotch",
                    isDirectory: true
                )
                .appendingPathComponent(
                    "Games",
                    isDirectory: true
                )

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory
    }

    var modsDirectory: URL {

        let directory =
            applicationSupportDirectory
                .appendingPathComponent(
                    "Butterscotch",
                    isDirectory: true
                )
                .appendingPathComponent(
                    "Mods",
                    isDirectory: true
                )

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory
    }

    func absolutePath(_ relative: String) -> String {

        gamesDirectory
            .appendingPathComponent(relative)
            .path
    }

    func dataWinURL(for game: Game) -> URL {
        gamesDirectory
            .appendingPathComponent(game.dataWinRel)
    }

    func directoryURL(for game: Game) -> URL {
        gamesDirectory
            .appendingPathComponent(game.dirRel)
    }

    func saveDirectoryURL(for game: Game) -> URL {
        gamesDirectory
            .appendingPathComponent(game.saveDirRel)
    }

    func iconURL(for game: Game) -> URL? {

        guard let iconRel = game.iconRel,
              !iconRel.isEmpty else {
            return nil
        }

        return gamesDirectory
            .appendingPathComponent(iconRel)
    }

    func icon(for game: Game) -> UIImage? {

        guard let url = iconURL(for: game) else {
            return nil
        }

        return UIImage(contentsOfFile: url.path)
    }

    // MARK: Mod Storage

    func modURL(for mod: Mod) -> URL {
        modsDirectory
            .appendingPathComponent(mod.fileRel)
    }

    func modPath(for mod: Mod) -> String {
        modURL(for: mod).path
    }

    // MARK: Persistence

    private func load() {

        // Games

        if let data =
            UserDefaults.standard.data(
                forKey: gamesKey
            ) {

            do {
                games =
                    try JSONDecoder().decode(
                        [Game].self,
                        from: data
                    )
            } catch {
                games = []
            }

        } else {
            games = []
        }

        // Mods

        if let data =
            UserDefaults.standard.data(
                forKey: modsKey
            ) {

            do {
                mods =
                    try JSONDecoder().decode(
                        [Mod].self,
                        from: data
                    )
            } catch {
                mods = []
            }

        } else {
            mods = []
        }
    }

    private func saveGames() {

        guard let data =
            try? JSONEncoder().encode(games) else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: gamesKey
        )
    }

    private func saveMods() {

        guard let data =
            try? JSONEncoder().encode(mods) else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: modsKey
        )
    }

    // MARK: Games

    func add(_ game: Game) {

        games.append(game)
        saveGames()
    }

    func update(_ game: Game) {

        guard let index =
            games.firstIndex(where: {
                $0.id == game.id
            }) else {
            return
        }

        games[index] = game
        saveGames()
    }

    func delete(_ game: Game) {

        try? FileManager.default.removeItem(
            at: directoryURL(for: game)
        )

        games.removeAll {
            $0.id == game.id
        }

        saveGames()

        if selectedGameID == game.id {
            selectedGameID = nil
        }
    }

    // MARK: Mods

    func add(_ mod: Mod) {

        mods.append(mod)
        saveMods()
    }

    func update(_ mod: Mod) {

        guard let index =
            mods.firstIndex(where: {
                $0.id == mod.id
            }) else {
            return
        }

        mods[index] = mod
        saveMods()
    }

    func delete(_ mod: Mod) {

        try? FileManager.default.removeItem(
            at: modURL(for: mod)
        )

        mods.removeAll {
            $0.id == mod.id
        }

        saveMods()
    }

    // MARK: Selected game

    var selectedGameID: String? {

        get {
            UserDefaults.standard.string(
                forKey: selectedGameKey
            )
        }

        set {
            UserDefaults.standard.set(
                newValue,
                forKey: selectedGameKey
            )
        }
    }

    // MARK: - Save Backup & Restore

    /// Prepares a FileWrapper of the game's save directory to be exported as a ZIP
    func prepareBackupDocument(for game: Game) -> SaveBackupDocument? {
        let saveURL = saveDirectoryURL(for: game)
        
        // Ensure the save directory actually exists before zipping
        if !FileManager.default.fileExists(atPath: saveURL.path) {
            try? FileManager.default.createDirectory(at: saveURL, withIntermediateDirectories: true)
        }
        
        do {
            // FileWrapper automatically archives folders when processed by .fileExporter
            let directoryWrapper = try FileWrapper(url: saveURL, options: [])
            return SaveBackupDocument(directoryWrapper: directoryWrapper)
        } catch {
            print("Error preparing backup wrapper: \(error)")
            return nil
        }
    }

    /// Extracted imported ZIP file wrapper into the game's save directory
    func importBackup(
        from zipURL: URL,
        for game: Game
    ) -> Bool {

        let saveURL = saveDirectoryURL(for: game)
        let fileManager = FileManager.default

        do {

            if fileManager.fileExists(atPath: saveURL.path) {
                try fileManager.removeItem(at: saveURL)
            }

            try fileManager.createDirectory(
                at: saveURL,
                withIntermediateDirectories: true
            )

            var errorBuffer = [CChar](
                repeating: 0,
                count: 512
            )

            let extracted =
                IOSZipImport_extractDirectory(
                    zipURL.path,
                    saveURL.path,
                    &errorBuffer,
                    errorBuffer.count
                )

            guard extracted else {

                let message =
                    String(cString: errorBuffer)

                print(
                    "Save import failed: \(message)"
                )

                return false
            }

            objectWillChange.send()

            return true

        } catch {

            print(
                "Error importing backup: \(error)"
            )

            return false
        }
    }

    func importSaveFolder(
        from sourceURL: URL,
        for game: Game
    ) -> Bool {

        let fileManager = FileManager.default
        let saveURL = saveDirectoryURL(for: game)

        let accessing =
            sourceURL.startAccessingSecurityScopedResource()

        defer {
            if accessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            var isDirectory: ObjCBool = false

            guard fileManager.fileExists(
                atPath: sourceURL.path,
                isDirectory: &isDirectory
            ),
            isDirectory.boolValue else {
                print("Selected save backup is not a folder.")
                return false
            }

            // Make sure the destination exists.
            try fileManager.createDirectory(
                at: saveURL,
                withIntermediateDirectories: true
            )

            // Remove the existing saves.
            let existingItems =
                try fileManager.contentsOfDirectory(
                    at: saveURL,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )

            for item in existingItems {
                try fileManager.removeItem(at: item)
            }

            // Copy the selected folder's contents into Saves/.
            let importedItems =
                try fileManager.contentsOfDirectory(
                    at: sourceURL,
                    includingPropertiesForKeys: nil,
                    options: []
                )

            for item in importedItems {

                let destination =
                    saveURL.appendingPathComponent(
                        item.lastPathComponent,
                        isDirectory: item.hasDirectoryPath
                    )

                try fileManager.copyItem(
                    at: item,
                    to: destination
                )
            }

            objectWillChange.send()

            return true

        } catch {
            print(
                "Save folder import failed: \(error)"
            )

            return false
        }
    }
}
