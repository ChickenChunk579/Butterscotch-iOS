#ifndef BUTTERSCOTCH_IOS_TOUCH_CONTROLS_H
#define BUTTERSCOTCH_IOS_TOUCH_CONTROLS_H

#include <stdbool.h>
#include <stdint.h>

typedef void (*IOSTouchControlsKeyCallback)(int32_t key, bool down);
typedef void (*IOSTouchControlsExitCallback)(void);

// Adds the native UIKit overlay to an SDL iOS window. The callback is invoked
// whenever a virtual control changes its held-key state.
void IOSTouchControls_install(void *sdlWindow, IOSTouchControlsKeyCallback callback,
                              IOSTouchControlsExitCallback exitCallback,
                              bool showControls, bool showFPS);
void IOSTouchControls_remove(void);
void IOSTouchControls_setFPS(double fps);

#endif
