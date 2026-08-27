package com.butterscotch.butterscotch

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import java.text.DateFormat
import java.util.Date

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GameDetailView(
    game: Game,
    onPlay: () -> Unit,
    onBack: (() -> Unit)? = null
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(
                MaterialTheme.colorScheme.background
            )
    ) {
        TopAppBar(
            title = {
                Text(game.name)
            }
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(
                    rememberScrollState()
                )
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(28.dp)
        ) {
            Hero(game)

            AboutSection(
                game = game,
                onPlay = {
                    val startTime =
                        System.currentTimeMillis()

                    onPlay()

                    val updatedGame = game.copy(
                        lastPlayed =
                            System.currentTimeMillis(),
                        playTime =
                            game.playTime +
                                (
                                    System.currentTimeMillis() -
                                        startTime
                                    )
                    )

                    GameStoreHolder.update(
                        updatedGame
                    )
                }
            )
        }
    }
}

/**
 * Temporary holder so this view can update GameStore.
 *
 * If you already have a GameStore instance available
 * from your navigation/root composable, pass an update
 * callback instead and this can be removed.
 */
private object GameStoreHolder {

    var store: GameStore? = null

    fun update(game: Game) {
        store?.update(game)
    }
}

@Composable
private fun Hero(
    game: Game
) {
    val store = GameStoreHolder.store

    val iconFile = store?.iconFile(game)

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(
                elevation = 15.dp,
                shape = RoundedCornerShape(22.dp)
            )
            .clip(
                RoundedCornerShape(22.dp)
            )
            .background(
                Brush.linearGradient(
                    listOf(
                        MaterialTheme.colorScheme.primary
                            .copy(alpha = 0.7f),
                        Color.Black.copy(alpha = 0.95f)
                    )
                )
            )
    ) {
        if (iconFile != null && iconFile.exists()) {
            AsyncImage(
                model = iconFile,
                contentDescription = game.name,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(
                        RoundedCornerShape(22.dp)
                    ),
                contentScale = ContentScale.Fit
            )
        } else {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(250.dp),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    painter = painterResource(
                        id = R.drawable.ic_games
                    ),
                    contentDescription = null,
                    modifier = Modifier.size(110.dp),
                    tint = Color.White.copy(
                        alpha = 0.12f
                    )
                )
            }
        }
    }
}

@Composable
private fun AboutSection(
    game: Game,
    onPlay: () -> Unit
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        ResponsiveActionRow(
            game = game,
            onPlay = onPlay
        )

        Column(
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            SectionHeader(
                title = "About",
                icon = R.drawable.ic_text
            )

            Text(
                text = game.description,
                style = MaterialTheme.typography.bodyMedium,
                color =
                    MaterialTheme.colorScheme.onSurfaceVariant,
                lineHeight = 22.sp,
                maxLines = 4
            )
        }

        InformationCard(game)
    }
}

@Composable
private fun ResponsiveActionRow(
    game: Game,
    onPlay: () -> Unit
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Button(
            onClick = onPlay,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor =
                    MaterialTheme.colorScheme.primary
            )
        ) {
            Icon(
                painter = painterResource(
                    id = R.drawable.ic_play
                ),
                contentDescription = null
            )

            Spacer(
                modifier = Modifier.width(9.dp)
            )

            Text(
                text = "Play",
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement =
                Arrangement.spacedBy(12.dp)
        ) {
            StatCard(
                title = "Play time",
                value =
                    formatDuration(
                        game.playTime
                    ),
                icon = R.drawable.ic_schedule,
                modifier = Modifier.weight(1f)
            )

            StatCard(
                title = "Last Played",
                value =
                    relativeDate(
                        game.lastPlayed
                    ),
                icon = R.drawable.ic_calendar,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun InformationCard(
    game: Game
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(
            containerColor =
                MaterialTheme.colorScheme.surfaceVariant
                    .copy(alpha = 0.35f)
        )
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement =
                Arrangement.spacedBy(20.dp)
        ) {
            GameInformation(game)

            HorizontalDivider(
                color =
                    MaterialTheme.colorScheme.outline
                        .copy(alpha = 0.15f)
            )

            Categories(game)
        }
    }
}

@Composable
private fun GameInformation(
    game: Game
) {
    Column(
        verticalArrangement =
            Arrangement.spacedBy(12.dp)
    ) {
        SectionHeader(
            title = "Game Information",
            icon = R.drawable.ic_info
        )

        Column(
            verticalArrangement =
                Arrangement.spacedBy(9.dp)
        ) {
            GameDetailRow(
                title = "Developers",
                value = game.developers
            )

            GameDetailRow(
                title = "Publisher",
                value = game.publisher
            )

            GameDetailRow(
                title = "Release Date",
                value =
                    relativeDate(
                        game.releaseDate
                    )
            )

            GameDetailRow(
                title = "Genres",
                value = game.genres
            )

            GameDetailRow(
                title = "Platforms",
                value = game.platforms
            )
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Categories(
    game: Game
) {
    Column(
        verticalArrangement =
            Arrangement.spacedBy(12.dp)
    ) {
        SectionHeader(
            title = "Categories",
            icon = R.drawable.ic_category
        )

        FlowRow(
            horizontalArrangement =
                Arrangement.spacedBy(8.dp),
            verticalArrangement =
                Arrangement.spacedBy(8.dp)
        ) {
            game.categories.forEach { category ->
                CategoryTag(category)
            }
        }
    }
}

@Composable
private fun SectionHeader(
    title: String,
    icon: Int
) {
    Row(
        verticalAlignment =
            Alignment.CenterVertically,
        horizontalArrangement =
            Arrangement.spacedBy(9.dp)
    ) {
        Icon(
            painter = painterResource(
                id = icon
            ),
            contentDescription = null,
            modifier = Modifier.size(18.dp),
            tint = MaterialTheme.colorScheme.primary
        )

        Text(
            text = title,
            style =
                MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
private fun StatCard(
    title: String,
    value: String,
    icon: Int,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(
            containerColor =
                MaterialTheme.colorScheme.surfaceVariant
                    .copy(alpha = 0.5f)
        )
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement =
                Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                painter = painterResource(
                    id = icon
                ),
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                tint = MaterialTheme.colorScheme.primary
            )

            Text(
                text = value,
                style =
                    MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )

            Text(
                text = title,
                style =
                    MaterialTheme.typography.bodySmall,
                color =
                    MaterialTheme.colorScheme
                        .onSurfaceVariant
            )
        }
    }
}

@Composable
private fun CategoryTag(
    title: String
) {
    Surface(
        shape = RoundedCornerShape(50),
        color =
            MaterialTheme.colorScheme.onSurface
                .copy(alpha = 0.06f)
    ) {
        Text(
            text = title,
            modifier = Modifier.padding(
                horizontal = 10.dp,
                vertical = 7.dp
            ),
            style =
                MaterialTheme.typography.labelMedium,
            color =
                MaterialTheme.colorScheme
                    .onSurfaceVariant,
            fontWeight = FontWeight.Medium
        )
    }
}

private fun formatDuration(
    milliseconds: Long
): String {
    val totalMinutes =
        milliseconds / 60_000

    val hours =
        totalMinutes / 60

    val minutes =
        totalMinutes % 60

    return when {
        hours > 0 && minutes > 0 ->
            "${hours}h ${minutes}m"

        hours > 0 ->
            "${hours}h"

        else ->
            "${minutes}m"
    }
}

private fun relativeDate(
    milliseconds: Long
): String {
    return DateFormat
        .getDateInstance(
            DateFormat.MEDIUM
        )
        .format(
            Date(milliseconds)
        )
}