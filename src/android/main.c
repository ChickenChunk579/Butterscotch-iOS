#include <android/log.h>

#include <log.h>

#include <stdio.h>
#include <stdarg.h>

#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION

#include <stb_image.h>
#include <stb_image_write.h>

void platformLog(const logType type, const char *format, va_list va)
{
    int priority;

    switch (type) {
        case LOG_TYPE_DEBUG:
            priority = ANDROID_LOG_DEBUG;
            break;

        case LOG_TYPE_NORMAL:
            priority = ANDROID_LOG_INFO;
            break;

        case LOG_TYPE_WARNING:
            priority = ANDROID_LOG_WARN;
            break;

        case LOG_TYPE_ERROR:
            priority = ANDROID_LOG_ERROR;
            break;

        default:
            priority = ANDROID_LOG_INFO;
            break;
    }

    __android_log_vprint(priority, "Butterscotch", format, va);
}