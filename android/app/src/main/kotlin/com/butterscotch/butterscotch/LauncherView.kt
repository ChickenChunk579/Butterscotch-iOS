package com.butterscotch.butterscotch

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource

@Composable
fun LauncherView() {

    var selectedTab by rememberSaveable {
        mutableIntStateOf(1)
    }

    var selectedGame by remember {
        mutableStateOf<Game?>(null)
    }

    Scaffold(
        bottomBar = {
            NavigationBar {

                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = {
                        selectedTab = 0
                        selectedGame = null
                    },
                    icon = {
                        Icon(
                            painter = painterResource(
                                R.drawable.ic_settings
                            ),
                            contentDescription = "Settings",
                            tint = MaterialTheme.colorScheme.primary
                        )
                    },
                    label = {
                        Text("Settings")
                    }
                )

                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = {
                        selectedTab = 1
                    },
                    icon = {
                        Icon(
                            painter = painterResource(
                                R.drawable.ic_games
                            ),
                            contentDescription = "Games",
                            tint = MaterialTheme.colorScheme.primary
                        )
                    },
                    label = {
                        Text("Games")
                    }
                )

                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = {
                        selectedTab = 2
                        selectedGame = null
                    },
                    icon = {
                        Icon(
                            painter = painterResource(
                                R.drawable.ic_info
                            ),
                            contentDescription = "About",
                            tint = MaterialTheme.colorScheme.primary
                        )
                    },
                    label = {
                        Text("About")
                    }
                )
            }
        }
    ) { padding ->

        if (selectedGame != null) {

            GameDetailView(
                game = selectedGame!!,
                onPlay = {
                    // Game launching will be connected here.
                },
                onBack = {
                    selectedGame = null
                }
            )

        } else {

            when (selectedTab) {

                0 -> SettingsView(
                    padding = padding
                )

                1 -> GamesView(
                    padding = padding,
                    onGameSelected = {
                        selectedGame = it
                    }
                )

                2 -> AboutView(
                    padding = padding
                )
            }
        }
    }
}