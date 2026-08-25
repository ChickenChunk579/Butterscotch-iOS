#import "launcher.h"

#ifdef __cplusplus
extern "C" {
#endif

int IOSLauncher_runApp(int argc, char *argv[]);
int IOSLauncher_setupApp(int argc, char *argv[]);

#ifdef __cplusplus
}
#endif

int IOSLauncher_runApp(int argc, char *argv[])
{
    return IOSLauncherInterface_runApp(argc, argv);
}

int IOSLauncher_setupApp(int argc, char *argv[])
{
    return IOSLauncherInterface_setupApp(argc, argv);
}