#import <UIKit/UIKit.h>

#import "butterscotch-Swift.h"

#import "launcher.h"
#import "zip_import.h"

void IOSLauncherStartGameFromSwift(
    NSString *dataWinPath,
    NSString *saveDirectory,
    BOOL lazyRooms,
    BOOL lazyTextures,
    BOOL lazyAudio,
    BOOL touchControls,
    BOOL showFPS,
    double speedMultiplier,
    float widescreenAspect
)
{
    IOSLaunchSettings settings = {
        .lazyRooms = lazyRooms,
        .lazyTextures = lazyTextures,
        .lazyAudio = lazyAudio,
        .touchControls = touchControls,
        .showFPS = showFPS,
        .speedMultiplier = speedMultiplier,
        .widescreenAspect = widescreenAspect
    };

    IOSLauncher_startGame(
        dataWinPath.fileSystemRepresentation,
        saveDirectory.fileSystemRepresentation,
        &settings,
        ""
    );
}

static UIWindow *launcherWindow = nil;
static char *launcherArgv0 = NULL;

static UIWindow *createLauncherWindow(void)
{
    UIWindow *window = nil;

    if (@available(iOS 13.0, *)) {

        for (UIScene *scene
             in [UIApplication sharedApplication].connectedScenes) {

            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            UIWindowScene *windowScene = (UIWindowScene *)scene;

            if (windowScene.activationState ==
                UISceneActivationStateUnattached) {
                continue;
            }

            window = [[UIWindow alloc]
                initWithWindowScene:windowScene];

            break;
        }
    }

    if (!window) {
        window = [[UIWindow alloc]
            initWithFrame:[UIScreen mainScreen].bounds];
    }

    window.backgroundColor =
        UIColor.systemBackgroundColor;

    return window;
}

static void rememberArgv0(int argc, char *argv[])
{
    (void)argc;

    if (launcherArgv0) {
        free(launcherArgv0);
        launcherArgv0 = NULL;
    }

    if (argv && argv[0]) {
        launcherArgv0 = strdup(argv[0]);
    }
}

int IOSLauncherInterface_runApp(int argc, char *argv[])
{
    rememberArgv0(argc, argv);

    @autoreleasepool {

        launcherWindow = createLauncherWindow();

        UIViewController *root =
            [SwiftUIBridge makeLauncherViewController];

        launcherWindow.rootViewController = root;

        [launcherWindow makeKeyAndVisible];

        [[NSRunLoop mainRunLoop] run];
    }

    return 0;
}

int IOSLauncherInterface_setupApp(int argc, char *argv[])
{
    rememberArgv0(argc, argv);

    @autoreleasepool {

        launcherWindow = createLauncherWindow();

        UIViewController *root =
            [SwiftUIBridge makeLauncherViewController];

        launcherWindow.rootViewController = root;

        [launcherWindow makeKeyAndVisible];
    }

    return 1;
}
