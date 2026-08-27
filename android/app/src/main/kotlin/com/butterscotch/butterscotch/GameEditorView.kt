package com.butterscotch.butterscotch

import android.app.DatePickerDialog
import android.content.Context
import android.widget.Toast
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GameEditorView(
    game: Game,
    onDismiss: () -> Unit
) {

    val context =
        LocalContext.current

    val store =
        remember {
            GameStore.getInstance(context)
        }

    val scope =
        rememberCoroutineScope()

    var name by remember {
        mutableStateOf(game.name)
    }

    var developers by remember {
        mutableStateOf(game.developers)
    }

    var publisher by remember {
        mutableStateOf(game.publisher)
    }

    var description by remember {
        mutableStateOf(game.description)
    }

    var genres by remember {
        mutableStateOf(game.genres)
    }

    var platforms by remember {
        mutableStateOf(game.platforms)
    }

    var categories by remember {
        mutableStateOf(
            game.categories.joinToString(", ")
        )
    }

    var releaseDate by remember {
        mutableStateOf(game.releaseDate)
    }

    var steamAppID by remember {
        mutableStateOf(game.steamAppID)
    }

    var fetchFromSteam by remember {
        mutableStateOf(game.fetchFromSteam)
    }

    var isFetchingSteam by remember {
        mutableStateOf(false)
    }

    var errorMessage by remember {
        mutableStateOf<String?>(null)
    }

    fun saveManual() {

        val updatedGame =
            game.copy(
                name =
                    name.trim()
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
                    false,

                releaseDate =
                    releaseDate
            )

        store.update(updatedGame)
        onDismiss()
    }

    fun saveWithSteam() {

        val appID =
            steamAppID.trim()

        if (
            appID.isEmpty() ||
            appID.toIntOrNull() == null
        ) {

            errorMessage =
                "Enter a valid Steam App ID."

            return
        }

        isFetchingSteam = true
        errorMessage = null

        scope.launch {

            try {

                val details =
                    SteamAppDetailsService
                        .fetchDetails(appID)

                val updatedGame =
                    game.copy(

                        name =
                            details.name
                                .ifBlank {
                                    name
                                        .trim()
                                        .ifBlank {
                                            "Imported Game"
                                        }
                                },

                        developers =
                            details.developers
                                .joinToString(", ")
                                .ifBlank {
                                    developers
                                        .trim()
                                },

                        publisher =
                            details.publishers
                                .joinToString(", ")
                                .ifBlank {
                                    publisher
                                        .trim()
                                },

                        description =
                            details.shortDescription
                                .ifBlank {
                                    description
                                        .trim()
                                },

                        genres =
                            details.genres
                                .joinToString(", ")
                                .ifBlank {
                                    genres
                                        .trim()
                                },

                        platforms =
                            details.platforms
                                .joinToString(", ")
                                .ifBlank {
                                    platforms
                                        .trim()
                                },

                        categories =
                            details.categories,

                        steamAppID =
                            appID,

                        fetchFromSteam =
                            true,

                        releaseDate =
                            details.releaseDate
                                ?: releaseDate
                    )

                store.update(updatedGame)

                isFetchingSteam = false

                onDismiss()

            } catch (exception: Exception) {

                isFetchingSteam = false

                errorMessage =
                    exception.message
                        ?: "Unable to fetch metadata from Steam."
            }
        }
    }

    Scaffold(

        topBar = {

            TopAppBar(

                title = {
                    Text(
                        if (game.name.isBlank()) {
                            "Add Game"
                        } else {
                            "Edit Game"
                        }
                    )
                },

                navigationIcon = {

                    TextButton(
                        onClick = onDismiss,
                        enabled = !isFetchingSteam
                    ) {
                        Text("Cancel")
                    }
                },

                actions = {

                    if (isFetchingSteam) {
                        CircularProgressIndicator(
                            modifier = Modifier
                                .padding(end = 16.dp)
                                .padding(4.dp)
                        )
                    } else {
                        TextButton(
                            onClick = {
                                if (fetchFromSteam) {
                                    saveWithSteam()
                                } else {
                                    saveManual()
                                }
                            }
                        ) {
                            Text("Save")
                        }
                    }
                }
            )
        }

    ) { innerPadding ->

        Column(

            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(innerPadding)
                    .verticalScroll(
                        rememberScrollState()
                    )
                    .padding(16.dp),

            verticalArrangement =
                Arrangement.spacedBy(16.dp)
        ) {

            /*
             * Steam metadata switch.
             */
            Row(
                modifier =
                    Modifier.fillMaxWidth(),
                horizontalArrangement =
                    Arrangement.SpaceBetween
            ) {

                Column(
                    modifier =
                        Modifier.weight(1f)
                ) {

                    Text(
                        "Fetch Metadata From Steam",
                        style =
                            MaterialTheme
                                .typography
                                .titleMedium
                    )

                    Text(
                        "Automatically fill game information using the Steam App ID.",
                        style =
                            MaterialTheme
                                .typography
                                .bodySmall,
                        color =
                            MaterialTheme
                                .colorScheme
                                .onSurfaceVariant
                    )
                }

                Switch(
                    checked = fetchFromSteam,
                    onCheckedChange = {
                        fetchFromSteam = it
                    },
                    enabled = !isFetchingSteam
                )
            }

            HorizontalDivider()

            if (fetchFromSteam) {

                /*
                 * Steam mode.
                 *
                 * Everything except the Steam ID is hidden,
                 * just like the Swift editor.
                 */
                Text(
                    "Steam",
                    style =
                        MaterialTheme
                            .typography
                            .titleMedium
                )

                OutlinedTextField(
                    value = steamAppID,
                    onValueChange = {
                        steamAppID = it
                    },
                    modifier =
                        Modifier.fillMaxWidth(),
                    label = {
                        Text("Steam App ID")
                    },
                    singleLine = true,
                    enabled = !isFetchingSteam
                )

                Text(
                    "Metadata will be fetched automatically when you save.",
                    style =
                        MaterialTheme
                            .typography
                            .bodySmall,
                    color =
                        MaterialTheme
                            .colorScheme
                            .onSurfaceVariant
                )

            } else {

                /*
                 * Manual metadata editor.
                 */

                OutlinedTextField(
                    value = name,
                    onValueChange = {
                        name = it
                    },
                    modifier =
                        Modifier.fillMaxWidth(),
                    label = {
                        Text("Name")
                    },
                    singleLine = true
                )

                OutlinedTextField(
                    value = description,
                    onValueChange = {
                        description = it
                    },
                    modifier =
                        Modifier.fillMaxWidth(),
                    label = {
                        Text("Description")
                    },
                    minLines = 3
                )

                Text(
                    "Credits",
                    style =
                        MaterialTheme
                            .typography
                            .titleMedium
                )

                OutlinedTextField(
                    value = developers,
                    onValueChange = {
                        developers = it
                    },
                    modifier =
                        Modifier.fillMaxWidth(),
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
                    modifier =
                        Modifier.fillMaxWidth(),
                    label = {
                        Text("Publisher")
                    },
                    singleLine = true
                )

                Text(
                    "Classification",
                    style =
                        MaterialTheme
                            .typography
                            .titleMedium
                )

                OutlinedTextField(
                    value = genres,
                    onValueChange = {
                        genres = it
                    },
                    modifier =
                        Modifier.fillMaxWidth(),
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
                    modifier =
                        Modifier.fillMaxWidth(),
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
                    modifier =
                        Modifier.fillMaxWidth(),
                    label = {
                        Text("Categories")
                    },
                    minLines = 2
                )

                ReleaseDateField(
                    date = releaseDate,
                    onDateChanged = {
                        releaseDate = it
                    }
                )

                Text(
                    "Separate multiple categories with commas.",
                    style =
                        MaterialTheme
                            .typography
                            .bodySmall,
                    color =
                        MaterialTheme
                            .colorScheme
                            .onSurfaceVariant
                )
            }
        }
    }

    errorMessage?.let { message ->

        AlertDialog(

            onDismissRequest = {
                errorMessage = null
            },

            title = {
                Text("Steam Metadata Error")
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
 * ---------------------------------------------------------------------------
 * Release Date
 * ---------------------------------------------------------------------------
 */

@Composable
private fun ReleaseDateField(
    date: Long,
    onDateChanged: (Long) -> Unit
) {

    val context =
        LocalContext.current

    val dateText =
        remember(date) {
            formatReleaseDate(date)
        }

    Column(
        verticalArrangement =
            Arrangement.spacedBy(8.dp)
    ) {

        Text(
            "Release Date",
            style =
                MaterialTheme
                    .typography
                    .titleSmall
        )

        Row(
            modifier =
                Modifier.fillMaxWidth(),
            horizontalArrangement =
                Arrangement.spacedBy(12.dp)
        ) {

            Text(
                text =
                    if (date > 0L) {
                        dateText
                    } else {
                        "No release date"
                    },
                modifier =
                    Modifier.weight(1f),
                style =
                    MaterialTheme
                        .typography
                        .bodyLarge
            )

            Button(
                onClick = {

                    val calendar =
                        Calendar.getInstance()

                    if (date > 0L) {
                        calendar.timeInMillis = date
                    }

                    DatePickerDialog(

                        context,

                        { _, year, month, day ->

                            val selected =
                                Calendar.getInstance()

                            selected.set(
                                year,
                                month,
                                day,
                                12,
                                0,
                                0
                            )

                            selected.set(
                                Calendar.MILLISECOND,
                                0
                            )

                            onDateChanged(
                                selected.timeInMillis
                            )
                        },

                        calendar.get(
                            Calendar.YEAR
                        ),

                        calendar.get(
                            Calendar.MONTH
                        ),

                        calendar.get(
                            Calendar.DAY_OF_MONTH
                        )

                    ).show()
                }
            ) {
                Text("Choose")
            }
        }
    }
}

private fun formatReleaseDate(
    timestamp: Long
): String {

    if (timestamp <= 0L) {
        return "No release date"
    }

    return SimpleDateFormat(
        "d MMM, yyyy",
        Locale.US
    ).format(
        Date(timestamp)
    )
}