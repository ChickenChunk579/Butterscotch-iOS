package com.butterscotch.butterscotch

import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp

private const val PREFS_NAME = "butterscotch_settings"

@Composable
fun SettingsView(padding: PaddingValues) {
    val context = LocalContext.current

    val prefs = remember {
        context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )
    }

    // MARK: Loading

    var lazyRooms by remember {
        mutableStateOf(
            prefs.getBoolean("ios.lazyRooms", true)
        )
    }

    var lazyTextures by remember {
        mutableStateOf(
            prefs.getBoolean("ios.lazyTextures", true)
        )
    }

    var lazyAudio by remember {
        mutableStateOf(
            prefs.getBoolean("ios.lazyAudio", true)
        )
    }

    // MARK: Display

    var touchControls by remember {
        mutableStateOf(
            prefs.getBoolean("ios.touchControls", true)
        )
    }

    var showFPS by remember {
        mutableStateOf(
            prefs.getBoolean("ios.showFPS", true)
        )
    }

    var widescreen by remember {
        mutableStateOf(
            prefs.getBoolean("ios.widescreen", false)
        )
    }

    var widescreenAspect by remember {
        mutableFloatStateOf(
            prefs.getFloat(
                "ios.widescreenAspect",
                1.7777778f
            )
        )
    }

    // MARK: Window

    var windowWidth by remember {
        mutableIntStateOf(
            prefs.getInt("ios.windowWidth", 0)
        )
    }

    var windowHeight by remember {
        mutableIntStateOf(
            prefs.getInt("ios.windowHeight", 0)
        )
    }

    // MARK: Performance

    var speed by remember {
        mutableFloatStateOf(
            prefs.getFloat("ios.speed", 1.0f)
        )
    }

    // MARK: Debugging

    var debug by remember {
        mutableStateOf(
            prefs.getBoolean("ios.debug", false)
        )
    }

    var disassemble by remember {
        mutableStateOf(
            prefs.getBoolean("ios.disassemble", false)
        )
    }

    var traceFrames by remember {
        mutableStateOf(
            prefs.getBoolean("ios.traceFrames", false)
        )
    }

    var traceEventInherited by remember {
        mutableStateOf(
            prefs.getBoolean(
                "ios.traceEventInherited",
                false
            )
        )
    }

    var alwaysLogUnknownFunctions by remember {
        mutableStateOf(
            prefs.getBoolean(
                "ios.alwaysLogUnknownFunctions",
                false
            )
        )
    }

    var alwaysLogStubbedFunctions by remember {
        mutableStateOf(
            prefs.getBoolean(
                "ios.alwaysLogStubbedFunctions",
                false
            )
        )
    }

    var disableLogColours by remember {
        mutableStateOf(
            prefs.getBoolean(
                "ios.disableLogColours",
                false
            )
        )
    }

    // MARK: Printing

    var printRooms by remember {
        mutableStateOf(
            prefs.getBoolean("ios.printRooms", false)
        )
    }

    var printObjects by remember {
        mutableStateOf(
            prefs.getBoolean("ios.printObjects", false)
        )
    }

    var printShaders by remember {
        mutableStateOf(
            prefs.getBoolean("ios.printShaders", false)
        )
    }

    var printDeclaredFunctions by remember {
        mutableStateOf(
            prefs.getBoolean(
                "ios.printDeclaredFunctions",
                false
            )
        )
    }

    var printUnknownFunctions by remember {
        mutableStateOf(
            prefs.getBoolean(
                "ios.printUnknownFunctions",
                false
            )
        )
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(padding)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {

        // MARK: Loading

        SettingsSection("Loading")

        SettingSwitch(
            title = "Lazy room loading",
            checked = lazyRooms,
            onCheckedChange = {
                lazyRooms = it
                prefs.edit()
                    .putBoolean("ios.lazyRooms", it)
                    .apply()
            }
        )

        SettingSwitch(
            title = "Lazy texture loading",
            checked = lazyTextures,
            onCheckedChange = {
                lazyTextures = it
                prefs.edit()
                    .putBoolean("ios.lazyTextures", it)
                    .apply()
            }
        )

        SettingSwitch(
            title = "Lazy audio loading",
            checked = lazyAudio,
            onCheckedChange = {
                lazyAudio = it
                prefs.edit()
                    .putBoolean("ios.lazyAudio", it)
                    .apply()
            }
        )

        SettingsDivider()

        // MARK: Display

        SettingsSection("Display & Controls")

        SettingSwitch(
            title = "Touch controls",
            checked = touchControls,
            onCheckedChange = {
                touchControls = it
                prefs.edit()
                    .putBoolean("ios.touchControls", it)
                    .apply()
            }
        )

        SettingSwitch(
            title = "FPS",
            checked = showFPS,
            onCheckedChange = {
                showFPS = it
                prefs.edit()
                    .putBoolean("ios.showFPS", it)
                    .apply()
            }
        )

        SettingSwitch(
            title = "Widescreen",
            checked = widescreen,
            onCheckedChange = {
                widescreen = it
                prefs.edit()
                    .putBoolean("ios.widescreen", it)
                    .apply()
            }
        )

        if (widescreen) {
            SettingChoice(
                title = "Aspect ratio",
                options = listOf(
                    "16:9",
                    "16:10",
                    "21:9",
                    "4:3"
                ),
                selected = when (widescreenAspect) {
                    1.6f -> 1
                    2.3333333f -> 2
                    1.3333333f -> 3
                    else -> 0
                },
                onSelected = {
                    widescreenAspect = when (it) {
                        1 -> 1.6f
                        2 -> 2.3333333f
                        3 -> 1.3333333f
                        else -> 1.7777778f
                    }

                    prefs.edit()
                        .putFloat(
                            "ios.widescreenAspect",
                            widescreenAspect
                        )
                        .apply()
                }
            )
        }

        SettingsDivider()

        // MARK: Window Size

        SettingsSection("Window Size")

        StepperSetting(
            title = "Width",
            value = windowWidth,
            displayValue =
                if (windowWidth == 0) "Auto"
                else "$windowWidth",
            range = 0..7680,
            onValueChange = {
                windowWidth = it

                prefs.edit()
                    .putInt("ios.windowWidth", it)
                    .apply()
            }
        )

        StepperSetting(
            title = "Height",
            value = windowHeight,
            displayValue =
                if (windowHeight == 0) "Auto"
                else "$windowHeight",
            range = 0..4320,
            onValueChange = {
                windowHeight = it

                prefs.edit()
                    .putInt("ios.windowHeight", it)
                    .apply()
            }
        )

        if (windowWidth != 0 || windowHeight != 0) {
            OutlinedButton(
                onClick = {
                    windowWidth = 0
                    windowHeight = 0

                    prefs.edit()
                        .putInt("ios.windowWidth", 0)
                        .putInt("ios.windowHeight", 0)
                        .apply()
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Reset to Auto")
            }
        }

        SettingsDivider()

        // MARK: Performance

        SettingsSection("Performance")

        Text(
            text = "Game speed: ${speed}×",
            style = MaterialTheme.typography.bodyLarge
        )

        Slider(
            value = speed,
            onValueChange = {
                speed = it

                prefs.edit()
                    .putFloat("ios.speed", it)
                    .apply()
            },
            valueRange = 0.5f..3.0f,
            steps = 4
        )

        SettingsDivider()

        // MARK: Debugging

        SettingsSection("Debugging")

        SettingSwitch(
            title = "Debug mode",
            checked = debug,
            onCheckedChange = {
                debug = it
                prefs.edit()
                    .putBoolean("ios.debug", it)
                    .apply()
            }
        )

        SettingSwitch(
            title = "Disassemble",
            checked = disassemble,
            onCheckedChange = {
                disassemble = it
                prefs.edit()
                    .putBoolean("ios.disassemble", it)
                    .apply()
            }
        )

        SettingSwitch(
            title = "Trace frames",
            checked = traceFrames,
            onCheckedChange = {
                traceFrames = it
                prefs.edit()
                    .putBoolean("ios.traceFrames", it)
                    .apply()
            }
        )

        SettingSwitch(
            title = "Trace inherited events",
            checked = traceEventInherited,
            onCheckedChange = {
                traceEventInherited = it
                prefs.edit()
                    .putBoolean(
                        "ios.traceEventInherited",
                        it
                    )
                    .apply()
            }
        )

        SettingSwitch(
            title = "Log unknown functions",
            checked = alwaysLogUnknownFunctions,
            onCheckedChange = {
                alwaysLogUnknownFunctions = it
                prefs.edit()
                    .putBoolean(
                        "ios.alwaysLogUnknownFunctions",
                        it
                    )
                    .apply()
            }
        )

        SettingSwitch(
            title = "Log stubbed functions",
            checked = alwaysLogStubbedFunctions,
            onCheckedChange = {
                alwaysLogStubbedFunctions = it
                prefs.edit()
                    .putBoolean(
                        "ios.alwaysLogStubbedFunctions",
                        it
                    )
                    .apply()
            }
        )

        SettingSwitch(
            title = "Disable log colours",
            checked = disableLogColours,
            onCheckedChange = {
                disableLogColours = it
                prefs.edit()
                    .putBoolean(
                        "ios.disableLogColours",
                        it
                    )
                    .apply()
            }
        )

        SettingsDivider()

        // MARK: Debug Output

        SettingsSection("Debug Output")

        SettingSwitch(
            title = "Print rooms",
            checked = printRooms,
            onCheckedChange = {
                printRooms = it
                prefs.edit()
                    .putBoolean("ios.printRooms", it)
                    .apply()
            }
        )

        SettingSwitch(
            title = "Print objects",
            checked = printObjects,
            onCheckedChange = {
                printObjects = it
                prefs.edit()
                    .putBoolean("ios.printObjects", it)
                    .apply()
            }
        )

        SettingSwitch(
            title = "Print shaders",
            checked = printShaders,
            onCheckedChange = {
                printShaders = it
                prefs.edit()
                    .putBoolean("ios.printShaders", it)
                    .apply()
            }
        )

        SettingSwitch(
            title = "Print declared functions",
            checked = printDeclaredFunctions,
            onCheckedChange = {
                printDeclaredFunctions = it
                prefs.edit()
                    .putBoolean(
                        "ios.printDeclaredFunctions",
                        it
                    )
                    .apply()
            }
        )

        SettingSwitch(
            title = "Print unknown functions",
            checked = printUnknownFunctions,
            onCheckedChange = {
                printUnknownFunctions = it
                prefs.edit()
                    .putBoolean(
                        "ios.printUnknownFunctions",
                        it
                    )
                    .apply()
            }
        )

        SettingsDivider()

        Button(
            onClick = {
                resetSettings(prefs)
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Reset All Settings")
        }
    }
}

@Composable
private fun SettingsSection(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleLarge,
        modifier = Modifier.padding(
            top = 12.dp,
            bottom = 4.dp
        )
    )
}

@Composable
private fun SettingsDivider() {
    HorizontalDivider(
        modifier = Modifier.padding(
            vertical = 12.dp
        )
    )
}

@Composable
private fun SettingSwitch(
    title: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            modifier = Modifier.weight(1f)
        )

        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange
        )
    }
}

@Composable
private fun SettingChoice(
    title: String,
    options: List<String>,
    selected: Int,
    onSelected: (Int) -> Unit
) {
    Column {
        Text(
            text = title,
            style = MaterialTheme.typography.bodyLarge
        )

        Row(
            modifier = Modifier.fillMaxWidth()
        ) {
            options.forEachIndexed { index, option ->
                OutlinedButton(
                    onClick = {
                        onSelected(index)
                    },
                    modifier = Modifier.weight(1f)
                ) {
                    Text(option)
                }
            }
        }
    }
}

@Composable
private fun StepperSetting(
    title: String,
    value: Int,
    displayValue: String,
    range: IntRange,
    onValueChange: (Int) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(
            modifier = Modifier.weight(1f)
        ) {
            Text(title)

            Text(
                text = displayValue,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        OutlinedButton(
            onClick = {
                if (value > range.first) {
                    onValueChange(value - 1)
                }
            }
        ) {
            Text("−")
        }

        OutlinedButton(
            onClick = {
                if (value < range.last) {
                    onValueChange(value + 1)
                }
            }
        ) {
            Text("+")
        }
    }
}

private fun resetSettings(
    prefs: android.content.SharedPreferences
) {
    prefs.edit()
        .clear()
        .apply()
}