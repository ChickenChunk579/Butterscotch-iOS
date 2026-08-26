#import <UIKit/UIKit.h>

#import <SDL2/SDL.h>
#import <SDL2/SDL_syswm.h>

#import "touch_controls.h"

/*
 * Xcode generates this header from the Swift target.
 *
 * If your Product Module Name is "butterscotch", this is:
 */
#import "butterscotch-Swift.h"


static TouchControlsViewController *gControlsController = nil;


// ============================================================================
// Install
// ============================================================================

void IOSTouchControls_install(
    void *sdlWindow,
    IOSTouchControlsKeyCallback callback,
    IOSTouchControlsExitCallback exitCallback,
    bool showControls,
    bool showFPS) {

    if (sdlWindow == NULL) {
        return;
    }

    SDL_SysWMinfo info;

    SDL_VERSION(&info.version);

    if (!SDL_GetWindowWMInfo(
            (SDL_Window *)sdlWindow,
            &info)) {
        return;
    }

    if (info.subsystem != SDL_SYSWM_UIKIT) {
        return;
    }

    UIWindow *window =
        info.info.uikit.window;

    if (window == nil) {
        return;
    }

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            // Remove previous overlay.

            if (gControlsController != nil) {

                [gControlsController.view
                    removeFromSuperview];

                gControlsController = nil;
            }

            // Create controller.

            gControlsController =
                [[TouchControlsViewController alloc]
                    initWithKeyCallback:callback
                    exitCallback:exitCallback
                    showControls:showControls
                    showFPS:showFPS];

            // Force view creation.

            UIView *overlay =
                gControlsController.view;

            overlay.frame =
                window.bounds;

            overlay.autoresizingMask =
                UIViewAutoresizingFlexibleWidth |
                UIViewAutoresizingFlexibleHeight;

            overlay.backgroundColor =
                UIColor.clearColor;

            overlay.opaque = NO;

            overlay.userInteractionEnabled = YES;

            // Put it over the SDL view.

            [window addSubview:overlay];

            [window bringSubviewToFront:overlay];

            NSLog(
                @"TouchControls: installed"
            );

            NSLog(
                @"TouchControls: overlay frame = %@",
                NSStringFromCGRect(
                    overlay.frame
                )
            );

            NSLog(
                @"TouchControls: interaction = %d",
                overlay.userInteractionEnabled
            );
        }
    );
}


// ============================================================================
// Remove
// ============================================================================

void IOSTouchControls_remove(void) {

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            if (gControlsController == nil) {
                return;
            }

            NSLog(
                @"TouchControls: removing"
            );

            [gControlsController.view
                removeFromSuperview];

            gControlsController = nil;
        }
    );
}


// ============================================================================
// FPS
// ============================================================================

void IOSTouchControls_setFPS(double fps) {

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            if (gControlsController != nil) {

                [gControlsController
                    setFPS:fps];
            }
        }
    );
}
