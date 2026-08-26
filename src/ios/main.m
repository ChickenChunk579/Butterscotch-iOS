
#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include <stb_image.h>
#include <stb_image_write.h>

#include <stdarg.h>
#include <log.h>

void platformLog(const logType type, const char *format, va_list va) {
    FILE *out = stderr;
    const char *textPrefix = "";

    switch (type) {
        case LOG_TYPE_NORMAL:
            out = stdout;
            break;

        case LOG_TYPE_WARNING:
            textPrefix = "Warning: ";
            break;

        case LOG_TYPE_ERROR:
            textPrefix = "Error: ";
            break;

        case LOG_TYPE_DEBUG:
            textPrefix = "Debug: ";
            break;
    }

    fputs(textPrefix, out);
    vfprintf(out, format, va);
}



#include <loop.h>
#include "launcher.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#endif

/* For SDL_main */
/*
#if defined(USE_SDL1)
#include <SDL/SDL_main.h>
#elif defined(USE_SDL2)
#include <SDL2/SDL_main.h>
#elif defined(USE_SDL3)
#include <SDL3/SDL_main.h>
#endif
*/
 
static bool touchControlsEnabled = true;
static bool showFPSEnabled = true;

bool IOSLauncher_touchControlsEnabled(void) {
    return touchControlsEnabled;
}

bool IOSLauncher_showFPSEnabled(void) {
    return showFPSEnabled;
}

int IOSLauncher_startGame(const char *dataWinPath, const char *saveFolder,
                          const IOSLaunchSettings *settings,
                          const char *argv0) {
    setbuf(stderr, NULL);
    setbuf(stdout, NULL);

    fprintf(stderr, "iOS: starting imported game\n");
    fprintf(stderr, "iOS: data.win: %s\n", dataWinPath);

    FILE *test = fopen(dataWinPath, "rb");

    if (!test) {
        fprintf(stderr, "iOS: ERROR: Could not open data.win at %s\n", dataWinPath);
        return 1;
    }

    fclose(test);

    fprintf(stderr, "iOS: data.win opened successfully\n");

    touchControlsEnabled = settings->touchControls;
    showFPSEnabled = settings->showFPS;

    CommandLineArgs args = {0};

    /*
     * Directly expose/copy the CommandLineArgs settings.
     */

    args.dataWinPath = dataWinPath;
    args.saveFolder = saveFolder;

#ifdef ENABLE_SCREENSHOTS

    args.screenshotPattern = settings->screenshotPattern;
    args.screenshotFrames = settings->screenshotFrames;

    args.screenshotSurfacesPattern = settings->screenshotSurfacesPattern;
    args.screenshotSurfacesFrames = settings->screenshotSurfacesFrames;

#endif

    args.dumpFrames = settings->dumpFrames;
    args.dumpJsonFrames = settings->dumpJsonFrames;
    args.dumpJsonFilePattern = settings->dumpJsonFilePattern;

#ifdef ENABLE_VM_TRACING

    args.varReadsToBeTraced = settings->varReadsToBeTraced;
    args.varWritesToBeTraced = settings->varWritesToBeTraced;
    args.functionCallsToBeTraced = settings->functionCallsToBeTraced;
    args.alarmsToBeTraced = settings->alarmsToBeTraced;
    args.instanceLifecyclesToBeTraced = settings->instanceLifecyclesToBeTraced;
    args.eventsToBeTraced = settings->eventsToBeTraced;
    args.collisionsToBeTraced = settings->collisionsToBeTraced;
    args.opcodesToBeTraced = settings->opcodesToBeTraced;
    args.stackToBeTraced = settings->stackToBeTraced;
    args.tilesToBeTraced = settings->tilesToBeTraced;

#endif

    args.disassemble = settings->disassemble;
    args.alwaysLogUnknownFunctions = settings->alwaysLogUnknownFunctions;

#ifdef ENABLE_VM_STUB_LOGS

    args.alwaysLogStubbedFunctions = settings->alwaysLogStubbedFunctions;

#endif

    args.headless = settings->headless;
    args.traceFrames = settings->traceFrames;
    args.printRooms = settings->printRooms;
    args.printObjects = settings->printObjects;
    args.printShaders = settings->printShaders;
    args.printDeclaredFunctions = settings->printDeclaredFunctions;
    args.printUnknownFunctions = settings->printUnknownFunctions;

    args.exitAtFrame = -1;

#ifdef ENABLE_VM_TRACING

    args.traceBytecodeAfterFrame = settings->traceBytecodeAfterFrame;

#endif

    args.speedMultiplier = settings->speedMultiplier;
    args.fastForwardSpeed = settings->fastForwardSpeed;

    args.seed = settings->seed;
    args.hasSeed = settings->hasSeed;

    args.debug = settings->debug;
    args.traceEventInherited = settings->traceEventInherited;

    args.recordInputsPath = settings->recordInputsPath;
    args.playbackInputsPath = settings->playbackInputsPath;

    args.renderer = settings->renderer;
    args.osType = settings->osType;

    args.windowWidth = settings->windowWidth;
    args.windowHeight = settings->windowHeight;

    args.widescreenAspect = settings->widescreenAspect;

    args.gameArgs = settings->gameArgs;

    args.lazyRooms = settings->lazyRooms;
    args.eagerRooms = settings->eagerRooms;

    args.lazyTextures = settings->lazyTextures;
    args.lazyAudio = settings->lazyAudio;

    args.loadType = settings->loadType;

    args.profilerFramesBetween = settings->profilerFramesBetween;

#ifdef ENABLE_VM_OPCODE_PROFILER

    args.opcodeProfiler = settings->opcodeProfiler;

#endif

    args.disableLogColours = settings->disableLogColours;

    fprintf(stderr, "iOS: calling loop()\n");

    int ret = loop(args, "");

    fprintf(stderr, "iOS: loop() returned %d\n", ret);

    return ret;
}

#import <UIKit/UIKit.h>

static int g_argc;
static char **g_argv;

@interface BSAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, retain) UIWindow *window;
@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        g_argc = argc;
        g_argv = argv;

        return UIApplicationMain(
            argc,
            argv,
            nil,
            NSStringFromClass([BSAppDelegate class])
        );
    }
}

@implementation BSAppDelegate

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    (void)application;
    (void)launchOptions;

    return IOSLauncher_setupApp(g_argc, g_argv);
}

@end
