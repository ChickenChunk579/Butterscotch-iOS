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
}
