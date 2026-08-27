package com.butterscotch.butterscotch

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.graphics.drawable.toBitmap

@Composable
fun GameCard(
    game: Game,
    modifier: Modifier = Modifier,
    onClick: () -> Unit = {}
) {
    val context = LocalContext.current

    var isPressed by remember {
        mutableStateOf(false)
    }

    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.97f else 1f,
        animationSpec = tween(120),
        label = "gameCardScale"
    )

    val accent = MaterialTheme.colorScheme.primary

    val shape = RoundedCornerShape(14.dp)

    Column(
        modifier = modifier
            .scale(scale)
            .clickable {
                onClick()
            },
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {

        // Artwork
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(6f / 9f)
                .clip(shape)
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            accent.copy(alpha = 0.75f),
                            Color.Black.copy(alpha = 0.9f)
                        )
                    )
                )
                .border(
                    width = 1.dp,
                    color = Color.White.copy(
                        alpha = if (isPressed) 0.25f else 0f
                    ),
                    shape = shape
                ),
            contentAlignment = Alignment.Center
        ) {

            val iconFile =
                GameStore
                    .getInstance(context)
                    .iconFile(game)

            if (
                iconFile != null &&
                iconFile.exists()
            ) {

                val drawable =
                    remember(iconFile.absolutePath) {
                        android.graphics.drawable.Drawable
                            .createFromPath(
                                iconFile.absolutePath
                            )
                    }

                if (drawable != null) {

                    Image(
                        bitmap = drawable
                            .toBitmap()
                            .asImageBitmap(),
                        contentDescription = game.name,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(shape),
                        contentScale = ContentScale.Crop
                    )

                } else {
                    GameCardFallbackIcon()
                }

            } else {
                GameCardFallbackIcon()
            }

            // Bottom gradient
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                Color.Transparent,
                                Color.Black.copy(alpha = 0.85f)
                            )
                        )
                    )
            )
        }

        // Name
        Text(
            text = game.name,
            style = MaterialTheme.typography.titleMedium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )

        // Developer
        Text(
            text = game.developers,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun GameCardFallbackIcon() {
    Image(
        painter = painterResource(
            id = R.drawable.ic_games
        ),
        contentDescription = null,
        modifier = Modifier.size(44.dp),
        contentScale = ContentScale.Fit
    )
}