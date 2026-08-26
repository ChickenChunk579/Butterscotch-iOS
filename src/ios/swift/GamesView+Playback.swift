import Foundation

extension GamesView {

    // MARK: - Play

    func play(_ game: Game) {

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

        settings.renderer =
            defaults.bool(
                forKey: "ios.metal"
            )
            ? METAL
            : MODERN_GL

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

    func gameDataPath(
        _ game: Game
    ) -> String {
        store.dataWinURL(
            for: game
        ).path
    }
}