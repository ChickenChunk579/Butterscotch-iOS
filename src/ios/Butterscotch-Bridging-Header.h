#pragma once

#import <Foundation/Foundation.h>

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
);