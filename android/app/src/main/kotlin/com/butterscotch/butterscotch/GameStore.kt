package com.butterscotch.butterscotch

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

@Serializable
data class Game(
    val id: String,

    var name: String,
    var developers: String,
    var publisher: String,
    var description: String,
    var genres: String,
    var platforms: String,
    var categories: List<String>,
    var steamAppID: String,
    var fetchFromSteam: Boolean,

    var dataWinRel: String,
    var dirRel: String,
    var saveDirRel: String,

    // Stored as milliseconds.
    var playTime: Long = 0L,
    var lastPlayed: Long = System.currentTimeMillis(),
    var releaseDate: Long = System.currentTimeMillis(),

    var iconRel: String? = null
)

@Serializable
data class Mod(
    val id: String,

    var name: String,

    /**
     * Path relative to the application's Mods directory.
     */
    var fileRel: String
)

class GameStore private constructor(
    private val context: Context
) {

    companion object {

        private const val PREFS_NAME =
            "butterscotch_game_store"

        private const val SETTINGS_PREFS_NAME =
            "butterscotch_settings"

        private const val GAMES_KEY =
            "ios.games"

        private const val MODS_KEY =
            "ios.mods"

        private const val SELECTED_GAME_KEY =
            "ios.selectedGame"

        @Volatile
        private var instance: GameStore? = null

        /**
         * Returns the application's singleton GameStore.
         */
        fun getInstance(context: Context): GameStore {
            return instance ?: synchronized(this) {
                instance ?: GameStore(
                    context.applicationContext
                ).also {
                    instance = it
                }
            }
        }

        /**
         * Registers the default settings used by the runner.
         *
         * These settings are persisted even though not all of them
         * are currently consumed by the Android runner.
         */
        fun registerDefaults(context: Context) {

            val prefs = context.getSharedPreferences(
                SETTINGS_PREFS_NAME,
                Context.MODE_PRIVATE
            )

            prefs.edit()
                .putBoolean(
                    "ios.lazyRooms",
                    true
                )
                .putBoolean(
                    "ios.lazyTextures",
                    true
                )
                .putBoolean(
                    "ios.lazyAudio",
                    true
                )
                .putBoolean(
                    "ios.touchControls",
                    true
                )
                .putFloat(
                    "ios.speed",
                    1.0f
                )
                .putBoolean(
                    "ios.widescreen",
                    false
                )
                .apply()
        }
    }

    private val prefs =
        context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    var games: List<Game> by mutableStateOf(emptyList())
        private set

    var mods: List<Mod> by mutableStateOf(emptyList())
        private set

    init {
        load()
    }

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------

    /**
     * Application-private storage directory.
     *
     * Equivalent to the iOS Application Support directory.
     */
    val applicationSupportDirectory: File
        get() {
            val directory = File(
                context.filesDir,
                "Butterscotch"
            )

            directory.mkdirs()

            return directory
        }

    /**
     * Directory containing installed games.
     */
    val gamesDirectory: File
        get() {
            val directory = File(
                applicationSupportDirectory,
                "Games"
            )

            directory.mkdirs()

            return directory
        }

    /**
     * Directory containing installed mods.
     */
    val modsDirectory: File
        get() {
            val directory = File(
                applicationSupportDirectory,
                "Mods"
            )

            directory.mkdirs()

            return directory
        }

    /**
     * Returns an absolute path inside the Games directory.
     */
    fun absolutePath(relative: String): String {
        return File(
            gamesDirectory,
            relative
        ).absolutePath
    }

    /**
     * Returns the game's data.win file.
     */
    fun dataWinFile(game: Game): File {
        return File(
            gamesDirectory,
            game.dataWinRel
        )
    }

    /**
     * Returns the game's directory.
     */
    fun directoryFile(game: Game): File {
        return File(
            gamesDirectory,
            game.dirRel
        )
    }

    /**
     * Returns the game's save directory.
     */
    fun saveDirectoryFile(game: Game): File {
        return File(
            gamesDirectory,
            game.saveDirRel
        )
    }

    /**
     * Returns the game's icon file, if one exists.
     */
    fun iconFile(game: Game): File? {

        val iconRel = game.iconRel

        if (iconRel.isNullOrEmpty()) {
            return null
        }

        return File(
            gamesDirectory,
            iconRel
        )
    }

    // -------------------------------------------------------------------------
    // Mod Storage
    // -------------------------------------------------------------------------

    fun modFile(mod: Mod): File {
        return File(
            modsDirectory,
            mod.fileRel
        )
    }

    fun modPath(mod: Mod): String {
        return modFile(mod).absolutePath
    }

    // -------------------------------------------------------------------------
    // Persistence
    // -------------------------------------------------------------------------

    private fun load() {
        games = loadList(GAMES_KEY)
        mods = loadList(MODS_KEY)
    }

    private inline fun <reified T> loadList(
        key: String
    ): List<T> {

        val data = prefs.getString(
            key,
            null
        ) ?: return emptyList()

        return try {
            json.decodeFromString<List<T>>(
                data
            )
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun saveGames() {

        val data = json.encodeToString(
            games
        )

        prefs.edit()
            .putString(
                GAMES_KEY,
                data
            )
            .apply()
    }

    private fun saveMods() {

        val data = json.encodeToString(
            mods
        )

        prefs.edit()
            .putString(
                MODS_KEY,
                data
            )
            .apply()
    }

    // -------------------------------------------------------------------------
    // Games
    // -------------------------------------------------------------------------

    fun add(game: Game) {

        games = games + game

        saveGames()
    }

    fun update(game: Game) {

        if (games.none { it.id == game.id }) {
            return
        }

        games = games.map {
            if (it.id == game.id) {
                game
            } else {
                it
            }
        }

        saveGames()
    }

    fun delete(game: Game) {

        directoryFile(game)
            .deleteRecursively()

        games = games.filter {
            it.id != game.id
        }

        saveGames()

        if (selectedGameID == game.id) {
            selectedGameID = null
        }
    }

    // -------------------------------------------------------------------------
    // Mods
    // -------------------------------------------------------------------------

    fun add(mod: Mod) {

        mods = mods + mod

        saveMods()
    }

    fun update(mod: Mod) {

        if (mods.none { it.id == mod.id }) {
            return
        }

        mods = mods.map {
            if (it.id == mod.id) {
                mod
            } else {
                it
            }
        }

        saveMods()
    }

    fun delete(mod: Mod) {

        modFile(mod)
            .deleteRecursively()

        mods = mods.filter {
            it.id != mod.id
        }

        saveMods()
    }

    // -------------------------------------------------------------------------
    // Selected Game
    // -------------------------------------------------------------------------

    var selectedGameID: String?
        get() {
            return prefs.getString(
                SELECTED_GAME_KEY,
                null
            )
        }

        set(value) {

            if (value == null) {
                prefs.edit()
                    .remove(SELECTED_GAME_KEY)
                    .apply()
            } else {
                prefs.edit()
                    .putString(
                        SELECTED_GAME_KEY,
                        value
                    )
                    .apply()
            }
        }

    val selectedGame: Game?
        get() {

            val id =
                selectedGameID
                    ?: return null

            return games.firstOrNull {
                it.id == id
            }
        }

    // -------------------------------------------------------------------------
    // Save Management
    // -------------------------------------------------------------------------

    /**
     * Ensures that the game's save directory exists.
     */
    fun ensureSaveDirectory(game: Game): File {

        val directory =
            saveDirectoryFile(game)

        directory.mkdirs()

        return directory
    }

    /**
     * Removes everything from the game's save directory.
     */
    fun clearSaveDirectory(game: Game) {

        val directory =
            ensureSaveDirectory(game)

        directory.listFiles()?.forEach {
            it.deleteRecursively()
        }
    }

    /**
     * Replaces the contents of the game's save directory with
     * the contents of [sourceDirectory].
     */
    fun importSaveFolder(
        sourceDirectory: File,
        game: Game
    ): Boolean {

        if (!sourceDirectory.isDirectory) {
            return false
        }

        return try {

            val destination =
                ensureSaveDirectory(game)

            destination.listFiles()?.forEach {
                it.deleteRecursively()
            }

            sourceDirectory.listFiles()?.forEach { source ->

                val target = File(
                    destination,
                    source.name
                )

                source.copyRecursively(
                    target,
                    overwrite = true
                )
            }

            true

        } catch (exception: Exception) {

            exception.printStackTrace()

            false
        }
    }
}