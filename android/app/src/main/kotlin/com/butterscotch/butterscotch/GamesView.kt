package com.butterscotch.butterscotch

import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import java.io.File
import java.io.FileOutputStream
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GamesView(
    padding: PaddingValues,
    onGameSelected: (Game) -> Unit = {}
) {
    val context = LocalContext.current

    val store = remember {
        GameStore.getInstance(context)
    }

    var selectedGame by remember {
        mutableStateOf<Game?>(null)
    }

    var editingGame by remember {
        mutableStateOf<Game?>(null)
    }

    var showDeleteDialog by remember {
        mutableStateOf(false)
    }

    var errorMessage by remember {
        mutableStateOf<String?>(null)
    }

    /*
     * -----------------------------------------------------------------------
     * Game ZIP picker
     * -----------------------------------------------------------------------
     */

    val gamePicker =
        rememberLauncherForActivityResult(
            contract = ActivityResultContracts.OpenDocument()
        ) { uri ->

            if (uri == null) {
                return@rememberLauncherForActivityResult
            }

            val result = GameImporter.import(
                context = context,
                uri = uri,
                store = store
            )

            result
                .onSuccess {
                    errorMessage = null
                }
                .onFailure { exception ->
                    errorMessage =
                        exception.message
                            ?: "Failed to import game."
                }
        }

    /*
     * -----------------------------------------------------------------------
     * Main screen
     * -----------------------------------------------------------------------
     */

    Scaffold(
        modifier = Modifier.padding(padding),

        topBar = {
            TopAppBar(
                title = {
                    Text("Games")
                }
            )
        },

        floatingActionButton = {
            FloatingActionButton(
                onClick = {
                    gamePicker.launch(
                        arrayOf(
                            "application/zip",
                            "application/x-zip-compressed",
                            "application/octet-stream"
                        )
                    )
                },
                containerColor =
                    MaterialTheme.colorScheme.primary,
                contentColor =
                    MaterialTheme.colorScheme.onPrimary
            ) {
                Icon(
                    painter = painterResource(
                        R.drawable.ic_add
                    ),
                    contentDescription = "Import Game"
                )
            }
        }
    ) { innerPadding ->

        if (store.games.isEmpty()) {

            EmptyGamesState(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
            )

        } else {

            GameLibrary(
                games = store.games,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                onGameSelected = onGameSelected,
                onGameMenu = {
                    selectedGame = it
                }
            )
        }
    }

    /*
     * -----------------------------------------------------------------------
     * Context menu
     * -----------------------------------------------------------------------
     */

    selectedGame?.let { game ->

        GameContextMenu(
            game = game,

            onDismiss = {
                selectedGame = null
            },

            onEdit = {
                /*
                 * IMPORTANT:
                 *
                 * Copy the selected game into editingGame before
                 * dismissing the menu.
                 */
                editingGame = game
                selectedGame = null
            },

            onBackup = {
                selectedGame = null

                /*
                 * Save backup can be implemented separately.
                 */
            },

            onImportSaves = {
                selectedGame = null

                /*
                 * Save import can be implemented separately.
                 */
            },

            onDelete = {
                showDeleteDialog = true
            }
        )
    }

    /*
     * -----------------------------------------------------------------------
     * Edit game
     * -----------------------------------------------------------------------
     */

    editingGame?.let { game ->

        GameEditorDialog(
            game = game,

            onDismiss = {
                editingGame = null
            },

            onSave = { updatedGame ->

                store.update(updatedGame)

                editingGame = null
            }
        )
    }

    /*
     * -----------------------------------------------------------------------
     * Delete confirmation
     * -----------------------------------------------------------------------
     */

    if (showDeleteDialog) {

        val game = selectedGame

        AlertDialog(
            onDismissRequest = {
                showDeleteDialog = false
                selectedGame = null
            },

            title = {
                Text("Delete Game?")
            },

            text = {
                Text(
                    if (game != null) {
                        "Are you sure you want to delete ${game.name}?"
                    } else {
                        "Are you sure you want to delete this game?"
                    }
                )
            },

            confirmButton = {

                TextButton(
                    onClick = {

                        game?.let {
                            store.delete(it)
                        }

                        showDeleteDialog = false
                        selectedGame = null
                    }
                ) {
                    Text("Delete")
                }
            },

            dismissButton = {

                TextButton(
                    onClick = {
                        showDeleteDialog = false
                        selectedGame = null
                    }
                ) {
                    Text("Cancel")
                }
            }
        )
    }

    /*
     * -----------------------------------------------------------------------
     * Import error
     * -----------------------------------------------------------------------
     */

    errorMessage?.let { message ->

        AlertDialog(
            onDismissRequest = {
                errorMessage = null
            },

            title = {
                Text("Import Failed")
            },

            text = {
                Text(message)
            },

            confirmButton = {

                TextButton(
                    onClick = {
                        errorMessage = null
                    }
                ) {
                    Text("OK")
                }
            }
        )
    }
}


/*
 * ===========================================================================
 * GAME EDITOR
 * ===========================================================================
 */

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun GameEditorDialog(
    game: Game,
    onDismiss: () -> Unit,
    onSave: (Game) -> Unit
) {
    var name by remember(game.id) {
        mutableStateOf(game.name)
    }

    var developers by remember(game.id) {
        mutableStateOf(game.developers)
    }

    var publisher by remember(game.id) {
        mutableStateOf(game.publisher)
    }

    var description by remember(game.id) {
        mutableStateOf(game.description)
    }

    var genres by remember(game.id) {
        mutableStateOf(game.genres)
    }

    var platforms by remember(game.id) {
        mutableStateOf(game.platforms)
    }

    var categories by remember(game.id) {
        mutableStateOf(
            game.categories.joinToString(", ")
        )
    }

    var steamAppID by remember(game.id) {
        mutableStateOf(game.steamAppID)
    }

    var fetchFromSteam by remember(game.id) {
        mutableStateOf(game.fetchFromSteam)
    }

    AlertDialog(
        onDismissRequest = onDismiss,

        title = {
            Text("Edit Game")
        },

        text = {

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(500.dp)
                    .verticalScroll(
                        rememberScrollState()
                    ),

                verticalArrangement =
                    Arrangement.spacedBy(12.dp)
            ) {

                OutlinedTextField(
                    value = name,
                    onValueChange = {
                        name = it
                    },
                    modifier = Modifier.fillMaxWidth(),
                    label = {
                        Text("Name")
                    },
                    singleLine = true
                )

                OutlinedTextField(
                    value = developers,
                    onValueChange = {
                        developers = it
                    },
                    modifier = Modifier.fillMaxWidth(),
                    label = {
                        Text("Developers")
                    },
                    singleLine = true
                )

                OutlinedTextField(
                    value = publisher,
                    onValueChange = {
                        publisher = it
                    },
                    modifier = Modifier.fillMaxWidth(),
                    label = {
                        Text("Publisher")
                    },
                    singleLine = true
                )

                OutlinedTextField(
                    value = description,
                    onValueChange = {
                        description = it
                    },
                    modifier = Modifier.fillMaxWidth(),
                    label = {
                        Text("Description")
                    },
                    minLines = 3
                )

                OutlinedTextField(
                    value = genres,
                    onValueChange = {
                        genres = it
                    },
                    modifier = Modifier.fillMaxWidth(),
                    label = {
                        Text("Genres")
                    },
                    singleLine = true
                )

                OutlinedTextField(
                    value = platforms,
                    onValueChange = {
                        platforms = it
                    },
                    modifier = Modifier.fillMaxWidth(),
                    label = {
                        Text("Platforms")
                    },
                    singleLine = true
                )

                OutlinedTextField(
                    value = categories,
                    onValueChange = {
                        categories = it
                    },
                    modifier = Modifier.fillMaxWidth(),
                    label = {
                        Text("Categories")
                    },
                    supportingText = {
                        Text("Separate categories with commas.")
                    }
                )

                OutlinedTextField(
                    value = steamAppID,
                    onValueChange = {
                        steamAppID = it
                    },
                    modifier = Modifier.fillMaxWidth(),
                    label = {
                        Text("Steam App ID")
                    },
                    singleLine = true
                )

                /*
                 * We keep the Steam setting editable.
                 *
                 * This doesn't fetch metadata yet; it simply preserves
                 * the same Game property used by the original Swift view.
                 */
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment =
                        Alignment.CenterVertically,
                    horizontalArrangement =
                        Arrangement.SpaceBetween
                ) {

                    Column(
                        modifier = Modifier.weight(1f)
                    ) {

                        Text(
                            text = "Fetch Metadata From Steam",
                            style =
                                MaterialTheme.typography.bodyLarge
                        )

                        Text(
                            text =
                                "Use the Steam App ID for metadata.",
                            style =
                                MaterialTheme.typography.bodySmall,
                            color =
                                MaterialTheme.colorScheme
                                    .onSurfaceVariant
                        )
                    }

                    androidx.compose.material3.Switch(
                        checked = fetchFromSteam,
                        onCheckedChange = {
                            fetchFromSteam = it
                        }
                    )
                }
            }
        },

        confirmButton = {

            TextButton(
                onClick = {

                    val updatedGame =
                        game.copy(
                            name =
                                name
                                    .trim()
                                    .ifEmpty {
                                        "Imported Game"
                                    },

                            developers =
                                developers.trim(),

                            publisher =
                                publisher.trim(),

                            description =
                                description.trim(),

                            genres =
                                genres.trim(),

                            platforms =
                                platforms.trim(),

                            categories =
                                categories
                                    .split(",")
                                    .map {
                                        it.trim()
                                    }
                                    .filter {
                                        it.isNotEmpty()
                                    },

                            steamAppID =
                                steamAppID.trim(),

                            fetchFromSteam =
                                fetchFromSteam
                        )

                    onSave(updatedGame)
                }
            ) {
                Text("Save")
            }
        },

        dismissButton = {

            TextButton(
                onClick = onDismiss
            ) {
                Text("Cancel")
            }
        }
    )
}


/*
 * ===========================================================================
 * GAME IMPORTER
 * ===========================================================================
 */

private object GameImporter {

    fun import(
        context: Context,
        uri: Uri,
        store: GameStore
    ): Result<Game> {

        return try {

            val originalName =
                getDisplayName(
                    context,
                    uri
                )

            val baseName =
                originalName
                    ?.substringBeforeLast(".")
                    ?.trim()
                    ?.takeIf {
                        it.isNotEmpty()
                    }
                    ?: "Imported Game"

            val gameID =
                UUID.randomUUID().toString()

            val safeDirectoryName =
                sanitizeFileName(
                    "$baseName-$gameID"
                )

            val gamesDirectory =
                store.gamesDirectory

            val gameDirectory =
                File(
                    gamesDirectory,
                    safeDirectoryName
                )

            if (!gameDirectory.mkdirs()) {

                if (!gameDirectory.isDirectory) {
                    throw IllegalStateException(
                        "Unable to create game directory."
                    )
                }
            }

            try {

                extractZip(
                    context = context,
                    uri = uri,
                    destination = gameDirectory
                )

                val dataWin =
                    findDataWin(
                        gameDirectory
                    )
                        ?: throw IllegalArgumentException(
                            "This ZIP does not contain a data.win file."
                        )

                val dataWinRelative =
                    relativePath(
                        gameDirectory,
                        dataWin
                    )

                val saveDirectory =
                    File(
                        gameDirectory,
                        "Saves"
                    )

                saveDirectory.mkdirs()

                val saveRelative =
                    relativePath(
                        gameDirectory,
                        saveDirectory
                    )

                val game =
                    Game(
                        id = gameID,

                        name = baseName,

                        developers = "Unknown",

                        publisher = "Unknown",

                        description =
                            "Imported GameMaker game.",

                        genres = "Unknown",

                        platforms = "Windows",

                        categories = emptyList(),

                        steamAppID = "",

                        fetchFromSteam = false,

                        dataWinRel =
                            dataWinRelative,

                        dirRel =
                            safeDirectoryName,

                        saveDirRel =
                            "$safeDirectoryName/$saveRelative"
                    )

                store.add(game)

                Result.success(game)

            } catch (exception: Exception) {

                gameDirectory.deleteRecursively()

                throw exception
            }

        } catch (exception: Exception) {

            Result.failure(
                exception
            )
        }
    }

    private fun extractZip(
        context: Context,
        uri: Uri,
        destination: File
    ) {

        val canonicalDestination =
            destination.canonicalFile

        context.contentResolver
            .openInputStream(uri)
            ?.use { input ->

                ZipInputStream(
                    input.buffered()
                ).use { zip ->

                    val buffer =
                        ByteArray(
                            16 * 1024
                        )

                    while (true) {

                        val entry =
                            zip.nextEntry
                                ?: break

                        if (entry.isDirectory) {

                            val directory =
                                safeZipFile(
                                    canonicalDestination,
                                    entry
                                )

                            directory.mkdirs()

                            zip.closeEntry()

                            continue
                        }

                        val outputFile =
                            safeZipFile(
                                canonicalDestination,
                                entry
                            )

                        outputFile.parentFile
                            ?.mkdirs()

                        FileOutputStream(
                            outputFile
                        ).use { output ->

                            while (true) {

                                val count =
                                    zip.read(
                                        buffer
                                    )

                                if (count <= 0) {
                                    break
                                }

                                output.write(
                                    buffer,
                                    0,
                                    count
                                )
                            }
                        }

                        zip.closeEntry()
                    }
                }

            }
                ?: throw IllegalStateException(
                    "Unable to open the selected ZIP file."
                )
    }

    private fun safeZipFile(
        destination: File,
        entry: ZipEntry
    ): File {

        val output =
            File(
                destination,
                entry.name
            ).canonicalFile

        val destinationPath =
            destination.path

        val outputPath =
            output.path

        if (
            outputPath != destinationPath &&
            !outputPath.startsWith(
                "$destinationPath${File.separator}"
            )
        ) {
            throw SecurityException(
                "Unsafe ZIP entry: ${entry.name}"
            )
        }

        return output
    }

    private fun findDataWin(
        directory: File
    ): File? {

        val files =
            directory.listFiles()
                ?: return null

        for (file in files) {

            if (
                file.isFile &&
                file.name.equals(
                    "data.win",
                    ignoreCase = true
                )
            ) {
                return file
            }

            if (file.isDirectory) {

                val result =
                    findDataWin(file)

                if (result != null) {
                    return result
                }
            }
        }

        return null
    }

    private fun relativePath(
        base: File,
        file: File
    ): String {

        val basePath =
            base
                .canonicalFile
                .toPath()

        val filePath =
            file
                .canonicalFile
                .toPath()

        return basePath
            .relativize(filePath)
            .toString()
            .replace(
                File.separatorChar,
                '/'
            )
    }

    private fun getDisplayName(
        context: Context,
        uri: Uri
    ): String? {

        val projection =
            arrayOf(
                android.provider.OpenableColumns
                    .DISPLAY_NAME
            )

        context.contentResolver
            .query(
                uri,
                projection,
                null,
                null,
                null
            )
            ?.use { cursor ->

                if (cursor.moveToFirst()) {

                    val index =
                        cursor.getColumnIndex(
                            android.provider.OpenableColumns
                                .DISPLAY_NAME
                        )

                    if (index >= 0) {
                        return cursor.getString(
                            index
                        )
                    }
                }
            }

        return null
    }

    private fun sanitizeFileName(
        value: String
    ): String {

        val sanitized =
            value
                .replace(
                    Regex(
                        """[\\/:*?"<>|]"""
                    ),
                    "_"
                )
                .trim()

        return sanitized
            .take(80)
            .ifEmpty {
                "Imported Game"
            }
    }
}


/*
 * ===========================================================================
 * GAME LIBRARY
 * ===========================================================================
 */

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun GameLibrary(
    games: List<Game>,
    modifier: Modifier = Modifier,
    onGameSelected: (Game) -> Unit,
    onGameMenu: (Game) -> Unit
) {
    LazyVerticalGrid(
        columns = GridCells.Adaptive(
            minSize = 150.dp
        ),

        modifier = modifier,

        contentPadding = PaddingValues(
            horizontal = 16.dp,
            vertical = 12.dp
        ),

        horizontalArrangement =
            Arrangement.spacedBy(12.dp),

        verticalArrangement =
            Arrangement.spacedBy(24.dp)
    ) {

        items(
            items = games,
            key = {
                it.id
            }
        ) { game ->

            Box {

                GameCard(
                    game = game,
                    modifier = Modifier
                        .fillMaxWidth()
                )

                /*
                 * Transparent interaction layer.
                 *
                 * Tap = open game
                 * Long press = context menu
                 */
                Box(
                    modifier = Modifier
                        .matchParentSize()
                        .combinedClickable(
                            onClick = {
                                onGameSelected(game)
                            },
                            onLongClick = {
                                onGameMenu(game)
                            }
                        )
                )
            }
        }
    }
}


/*
 * ===========================================================================
 * EMPTY STATE
 * ===========================================================================
 */

@Composable
private fun EmptyGamesState(
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center
    ) {

        Column(
            modifier = Modifier.padding(32.dp),

            horizontalAlignment =
                Alignment.CenterHorizontally,

            verticalArrangement =
                Arrangement.spacedBy(10.dp)
        ) {

            Icon(
                painter = painterResource(
                    R.drawable.ic_games
                ),
                contentDescription = null,
                modifier = Modifier.size(64.dp),
                tint =
                    MaterialTheme.colorScheme.primary
            )

            Text(
                text = "Your Library Is Empty",

                style =
                    MaterialTheme.typography
                        .headlineSmall,

                textAlign =
                    TextAlign.Center
            )

            Text(
                text =
                    "Tap + to import a GameMaker ZIP containing a data.win.",

                style =
                    MaterialTheme.typography
                        .bodyMedium,

                color =
                    MaterialTheme.colorScheme
                        .onSurfaceVariant,

                textAlign =
                    TextAlign.Center
            )
        }
    }
}


/*
 * ===========================================================================
 * CONTEXT MENU
 * ===========================================================================
 */

@Composable
private fun GameContextMenu(
    game: Game,
    onDismiss: () -> Unit,
    onEdit: () -> Unit,
    onBackup: () -> Unit,
    onImportSaves: () -> Unit,
    onDelete: () -> Unit
) {
    var expanded by remember {
        mutableStateOf(true)
    }

    DropdownMenu(
        expanded = expanded,

        onDismissRequest = {
            expanded = false
            onDismiss()
        }
    ) {

        DropdownMenuItem(
            text = {
                Text("Edit")
            },

            onClick = {
                expanded = false
                onEdit()
            },

            leadingIcon = {
                Icon(
                    painter = painterResource(
                        R.drawable.ic_edit
                    ),
                    contentDescription = null
                )
            }
        )

        DropdownMenuItem(
            text = {
                Text("Backup Saves")
            },

            onClick = {
                expanded = false
                onBackup()
            },

            leadingIcon = {
                Icon(
                    painter = painterResource(
                        R.drawable.ic_backup
                    ),
                    contentDescription = null
                )
            }
        )

        DropdownMenuItem(
            text = {
                Text("Import Saves")
            },

            onClick = {
                expanded = false
                onImportSaves()
            },

            leadingIcon = {
                Icon(
                    painter = painterResource(
                        R.drawable.ic_download
                    ),
                    contentDescription = null
                )
            }
        )

        DropdownMenuItem(
            text = {
                Text(
                    "Delete",
                    color =
                        MaterialTheme.colorScheme.error
                )
            },

            onClick = {
                expanded = false
                onDelete()
            },

            leadingIcon = {
                Icon(
                    painter = painterResource(
                        R.drawable.ic_delete
                    ),
                    contentDescription = null,
                    tint =
                        MaterialTheme.colorScheme.error
                )
            }
        )
    }
}