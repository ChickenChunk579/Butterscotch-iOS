#pragma once
#import <Foundation/Foundation.h>
#import "zip_import.h"
#include "platformdefs.h"

typedef struct IOSLaunchSettings {

    const char* dataWinPath;
    const char* saveFolder;

#ifdef ENABLE_SCREENSHOTS

    const char* screenshotPattern;
    FrameSetEntry* screenshotFrames;

    const char* screenshotSurfacesPattern;
    FrameSetEntry* screenshotSurfacesFrames;

#endif

    FrameSetEntry* dumpFrames;
    FrameSetEntry* dumpJsonFrames;
    const char* dumpJsonFilePattern;

#ifdef ENABLE_VM_TRACING

    StringBooleanEntry* varReadsToBeTraced;
    StringBooleanEntry* varWritesToBeTraced;
    StringBooleanEntry* functionCallsToBeTraced;
    StringBooleanEntry* alarmsToBeTraced;
    StringBooleanEntry* instanceLifecyclesToBeTraced;
    StringBooleanEntry* eventsToBeTraced;
    StringBooleanEntry* collisionsToBeTraced;
    StringBooleanEntry* opcodesToBeTraced;
    StringBooleanEntry* stackToBeTraced;
    StringBooleanEntry* tilesToBeTraced;

#endif

    StringBooleanEntry* disassemble;
    bool alwaysLogUnknownFunctions;

#ifdef ENABLE_VM_STUB_LOGS

    bool alwaysLogStubbedFunctions;

#endif

    bool headless;
    bool traceFrames;
    bool printRooms;
    bool printObjects;
    bool printShaders;
    bool printDeclaredFunctions;
    bool printUnknownFunctions;

    int exitAtFrame;

#ifdef ENABLE_VM_TRACING

    int traceBytecodeAfterFrame;

#endif

    double speedMultiplier;
    double fastForwardSpeed;

    int seed;
    bool hasSeed;

    bool debug;
    bool traceEventInherited;

    const char* recordInputsPath;
    const char* playbackInputsPath;

    enum GraphicsAPI renderer;
    YoYoOperatingSystem osType;

    int32_t windowWidth;
    int32_t windowHeight;

    float widescreenAspect;

    char** gameArgs;

    bool lazyRooms;
    StringBooleanEntry* eagerRooms;

    bool lazyTextures;
    bool lazyAudio;

    DataWinLoadType loadType;

    int profilerFramesBetween;

#ifdef ENABLE_VM_OPCODE_PROFILER

    bool opcodeProfiler;

#endif

    bool disableLogColours;

    /*
     * iOS-specific setting.
     */
    bool touchControls;
    bool showFPS;

} IOSLaunchSettings;


int IOSLauncher_startGame(const char *dataWinPath, const char *saveFolder,
                          const IOSLaunchSettings *settings,
                          const char *argv0);

int IOSLauncherInterface_runApp(int argc, char *argv[]);
int IOSLauncherInterface_setupApp(int argc, char *argv[]);

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
);

#ifdef __cplusplus
extern "C" {
#endif

int IOSLauncher_runApp(int argc, char *argv[]);
int IOSLauncher_setupApp(int argc, char *argv[]);

#ifdef __cplusplus
}
#endif