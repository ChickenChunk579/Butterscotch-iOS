cmake_minimum_required(VERSION 3.21)

# ==============================================================================
# Platform configuration
# ==============================================================================

if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    set(CMAKE_OSX_DEPLOYMENT_TARGET "17.0" CACHE STRING
        "Minimum iOS version" FORCE)

    set(BUTTERSCOTCH_PLATFORM "ios" CACHE STRING
        "Butterscotch platform" FORCE)

    set(BACKEND "sdl2" CACHE STRING
        "iOS backend" FORCE)
endif()

set(BUTTERSCOTCH_PLATFORM "cli" CACHE STRING
    "Butterscotch platform")

set(BACKEND "" CACHE STRING
    "Desktop Butterscotch backend")

set(AUDIO_BACKEND "" CACHE STRING
    "Audio backend")

# iOS is selected by the CMake system platform rather than requiring:
#   -DBUTTERSCOTCH_PLATFORM=ios
#
# This must happen before project() so the rest of this file can distinguish
# iOS from the normal desktop CLI target.
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    set(BUTTERSCOTCH_PLATFORM "ios" CACHE STRING
        "Butterscotch platform" FORCE)
    set(BACKEND "sdl2" CACHE STRING
        "iOS backend" FORCE)
endif()

# PS3 toolchain must be selected before project().
if(BUTTERSCOTCH_PLATFORM STREQUAL "ps3")
    set(CMAKE_TOOLCHAIN_FILE
        "${CMAKE_SOURCE_DIR}/cmake/ppu.cmake"
        CACHE FILEPATH "PS3 toolchain file")
endif()

# Vita toolchain must be selected before project().
if(BUTTERSCOTCH_PLATFORM STREQUAL "vita")
    if(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
        if(DEFINED ENV{VITASDK})
            set(CMAKE_TOOLCHAIN_FILE
                "$ENV{VITASDK}/share/vita.toolchain.cmake"
                CACHE PATH "Vita toolchain file")
        else()
            message(FATAL_ERROR
                "Please define VITASDK to point to your SDK path!")
        endif()
    endif()

    set(BACKEND "sdl2" CACHE STRING
        "Vita backend" FORCE)
endif()

project(butterscotch C OBJC CXX OBJCXX Swift)

# ==============================================================================
# iOS frameworks
# ==============================================================================

if(BUTTERSCOTCH_PLATFORM STREQUAL "ios")

    find_library(IOS_OPENGLES_FRAMEWORK
        OpenGLES
        REQUIRED
    )

    find_library(IOS_UIKIT_FRAMEWORK
        UIKit
        REQUIRED
    )

    find_library(IOS_FOUNDATION_FRAMEWORK
        Foundation
        REQUIRED
    )

    find_library(IOS_PHOTOS_FRAMEWORK
        Photos
        REQUIRED
    )

    find_library(IOS_PHOTOSUI_FRAMEWORK
        PhotosUI
        REQUIRED
    )

    find_library(IOS_UNIFORMTYPEIDENTIFIERS_FRAMEWORK
        UniformTypeIdentifiers
        REQUIRED
    )

    find_library(IOS_GAMECONTROLLER_FRAMEWORK
        GameController
    )

endif()

# ==============================================================================
# Vita configuration
# ==============================================================================

if(BUTTERSCOTCH_PLATFORM STREQUAL "vita")
    include("${VITASDK}/share/vita.cmake" REQUIRED)

    set(VITA_APP_NAME "Butterscotch")
    set(VITA_TITLEID "BUTTRSTCH")
    set(VITA_VERSION "01.00")
    set(VITA_MKSFOEX_FLAGS "-d ATTRIBUTE2=12")
endif()

# ==============================================================================
# Compiler configuration
# ==============================================================================

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

if(MSVC)
    if(WERROR)
        add_compile_options(/WX)
    endif()
else()
    add_compile_options(
        $<$<COMPILE_LANGUAGE:C>:-Wall>
        $<$<COMPILE_LANGUAGE:C>:-Wextra>
        $<$<COMPILE_LANGUAGE:C>:-Wvla>

        $<$<COMPILE_LANGUAGE:CXX>:-Wall>
        $<$<COMPILE_LANGUAGE:CXX>:-Wextra>

        $<$<COMPILE_LANGUAGE:OBJC>:-Wall>
        $<$<COMPILE_LANGUAGE:OBJC>:-Wextra>

        $<$<COMPILE_LANGUAGE:OBJCXX>:-Wall>
        $<$<COMPILE_LANGUAGE:OBJCXX>:-Wextra>
    )

    if(WERROR)
        add_compile_options(
            $<$<COMPILE_LANGUAGE:C>:-Werror>
            $<$<COMPILE_LANGUAGE:CXX>:-Werror>
            $<$<COMPILE_LANGUAGE:OBJC>:-Werror>
            $<$<COMPILE_LANGUAGE:OBJCXX>:-Werror>
        )
    endif()
endif()

if(NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
    if(MSVC)
        add_compile_options(/Oy)
    else()
        add_compile_options(
            $<$<COMPILE_LANGUAGE:C,CXX,OBJC,OBJCXX>:-ffast-math>
            $<$<COMPILE_LANGUAGE:C,CXX,OBJC,OBJCXX>:-fno-finite-math-only>
        )

        include(CheckCCompilerFlag)

        check_c_compiler_flag(
            "-fomit-frame-pointer"
            HAS_FOMIT_FRAME_POINTER
        )

        if(HAS_FOMIT_FRAME_POINTER)
            add_compile_options(
                $<$<COMPILE_LANGUAGE:C,CXX,OBJC,OBJCXX>:-fomit-frame-pointer>
            )
        endif()
    endif()
endif()

# iOS should not inherit desktop-only compiler assumptions.
if(BUTTERSCOTCH_PLATFORM STREQUAL "ios")
    # Don't use the desktop FORTIFY setup here.
    # Apple Clang/libSystem handles this itself.
endif()

# ==============================================================================
# Validation
# ==============================================================================

if(BUTTERSCOTCH_PLATFORM STREQUAL "cli" AND BACKEND STREQUAL "")
    message(FATAL_ERROR "You need to set a BACKEND!")
endif()

if(BUTTERSCOTCH_PLATFORM STREQUAL "ios" AND BACKEND STREQUAL "")
    set(BACKEND "sdl2")
endif()

# ==============================================================================
# Build metadata
# ==============================================================================

set(BUTTERSCOTCH_COMMIT_HASH "unknown"
    CACHE STRING "Git commit hash")

set(BUTTERSCOTCH_COMMIT_DATE "unknown"
    CACHE STRING "Git commit date")

add_compile_definitions(
    BUTTERSCOTCH_COMMIT_HASH="${BUTTERSCOTCH_COMMIT_HASH}"
    BUTTERSCOTCH_COMMIT_DATE="${BUTTERSCOTCH_COMMIT_DATE}"
)

# ==============================================================================
# Audio backend
# ==============================================================================

if(AUDIO_BACKEND STREQUAL "")
    if(BUTTERSCOTCH_PLATFORM STREQUAL "web")
        set(AUDIO_BACKEND "web")
    elseif(BUTTERSCOTCH_PLATFORM STREQUAL "web-meta")
        set(AUDIO_BACKEND "none")
    elseif(BUTTERSCOTCH_PLATFORM STREQUAL "ps3"
           OR BUTTERSCOTCH_PLATFORM STREQUAL "vita")
        set(AUDIO_BACKEND "openal")
    elseif(BUTTERSCOTCH_PLATFORM STREQUAL "ps2")
        set(AUDIO_BACKEND "ps2")
    else()
        # This includes desktop CLI, iOS and Android.
        set(AUDIO_BACKEND "miniaudio")
    endif()
endif()

message(STATUS "Butterscotch platform: ${BUTTERSCOTCH_PLATFORM}")
message(STATUS "Backend: ${BACKEND}")
message(STATUS "Audio backend: ${AUDIO_BACKEND}")

if(AUDIO_BACKEND STREQUAL "openal")

    file(GLOB AUDIO_SOURCES
        src/audio/openal/*.c
    )

elseif(AUDIO_BACKEND STREQUAL "miniaudio")

    file(GLOB AUDIO_SOURCES
        src/audio/miniaudio/*.c
        src/audio/miniaudio/*.m
    )

    if(BUTTERSCOTCH_PLATFORM STREQUAL "vita")
        add_compile_definitions(MA_NO_RUNTIME_LINKING)
    endif()

elseif(AUDIO_BACKEND STREQUAL "web")

    file(GLOB AUDIO_SOURCES
        src/audio/web/*.c
        src/audio/miniaudio/*.c
    )

elseif(AUDIO_BACKEND STREQUAL "ps2")

    file(GLOB AUDIO_SOURCES
        src/audio/ps2/*.c
    )

elseif(NOT AUDIO_BACKEND STREQUAL "none")

    message(FATAL_ERROR "Invalid AUDIO_BACKEND: ${AUDIO_BACKEND}")

endif()

# ==============================================================================
# WAD support / renderer options
# ==============================================================================

option(ENABLE_WAD14
    "Enable support for WAD Version 14 and below"
    ON)

option(ENABLE_WAD16
    "Enable support for WAD Version 15/16"
    ON)

option(ENABLE_WAD17
    "Enable support for WAD Version 17"
    ON)

option(ENABLE_LEGACY_GL
    "Enable the legacy OpenGL renderer"
    ON)

option(ENABLE_MODERN_GL
    "Enable the modern OpenGL renderer"
    ON)

# iOS must use the modern GLES renderer.
if(BUTTERSCOTCH_PLATFORM STREQUAL "ios")
    set(ENABLE_LEGACY_GL OFF CACHE BOOL
        "Enable the legacy OpenGL renderer" FORCE)

    set(ENABLE_MODERN_GL ON CACHE BOOL
        "Enable the modern OpenGL renderer" FORCE)
endif()

if(NOT ENABLE_WAD14 AND
   NOT ENABLE_WAD16 AND
   NOT ENABLE_WAD17)

    message(FATAL_ERROR
        "You need to build Butterscotch with at least one WAD version enabled!")

endif()

if(ENABLE_WAD14)
    add_compile_definitions(ENABLE_WAD14)
endif()

if(ENABLE_WAD16)
    add_compile_definitions(ENABLE_WAD16)
endif()

if(ENABLE_WAD17)
    add_compile_definitions(ENABLE_WAD17)
endif()

if(ENABLE_LEGACY_GL)
    add_compile_definitions(ENABLE_LEGACY_GL)
endif()

if(ENABLE_MODERN_GL)
    add_compile_definitions(ENABLE_MODERN_GL)
endif()

# ==============================================================================
# Sources
# ==============================================================================

if(BUTTERSCOTCH_PLATFORM STREQUAL "web-meta")

    set(SOURCES
        src/data_win.c
        src/binary_reader.c
        src/log.c
        src/stb_ds.c
    )

else()

    file(GLOB SOURCES
        src/*.c
    )

    if(BUTTERSCOTCH_PLATFORM STREQUAL "ps2"
       OR BUTTERSCOTCH_PLATFORM STREQUAL "ps3"
       OR BUTTERSCOTCH_PLATFORM STREQUAL "web"
       OR BUTTERSCOTCH_PLATFORM STREQUAL "android")

        list(REMOVE_ITEM SOURCES
            "${CMAKE_CURRENT_SOURCE_DIR}/src/loop.c"
        )

    endif()

endif()

file(GLOB BUTTERSCOTCH_PLATFORM_SOURCES
    src/${BUTTERSCOTCH_PLATFORM}/*.c
)

# The iOS touch-control overlay is implemented with UIKit.
if(BUTTERSCOTCH_PLATFORM STREQUAL "ios")
    file(GLOB BUTTERSCOTCH_PLATFORM_OBJC_SOURCES
        src/ios/*.m
    )
    file(GLOB BUTTERSCOTCH_PLATFORM_SWIFT_SOURCES
        src/ios/swift/*.swift
    )
    list(APPEND BUTTERSCOTCH_PLATFORM_SOURCES
        ${BUTTERSCOTCH_PLATFORM_OBJC_SOURCES}
        ${BUTTERSCOTCH_PLATFORM_SWIFT_SOURCES}
    )

    
endif()

# ==============================================================================
# Target
# ==============================================================================

if(BUTTERSCOTCH_PLATFORM STREQUAL "android")

    add_library(
        butterscotch
        SHARED
        ${SOURCES}
        ${BUTTERSCOTCH_PLATFORM_SOURCES}
        ${AUDIO_SOURCES}
    )

else()

    add_executable(
        butterscotch
        ${SOURCES}
        ${BUTTERSCOTCH_PLATFORM_SOURCES}
        ${AUDIO_SOURCES}
    )

endif()

target_include_directories(
    butterscotch
    PRIVATE
        ${CMAKE_SOURCE_DIR}/src
        ${CMAKE_SOURCE_DIR}/src/${BUTTERSCOTCH_PLATFORM}
)

# ==============================================================================
# Audio configuration
# ==============================================================================

if(AUDIO_BACKEND STREQUAL "openal")

    target_include_directories(
        butterscotch
        PUBLIC
            src/audio/openal
    )

    add_compile_definitions(USE_OPENAL)

    if(APPLE)

        set(AUDIO_LIBRARIES
            "-framework OpenAL"
        )

    elseif(BUTTERSCOTCH_PLATFORM STREQUAL "vita")

        set(AUDIO_LIBRARIES
            openal
            pthread
        )

    elseif(NOT BUTTERSCOTCH_PLATFORM STREQUAL "ps3")

        find_package(OpenAL REQUIRED)

        target_include_directories(
            butterscotch
            PUBLIC
                "${OPENAL_INCLUDE_DIR}"
        )

        set(AUDIO_LIBRARIES
            "${OPENAL_LIBRARY}"
        )

    endif()

elseif(AUDIO_BACKEND STREQUAL "miniaudio")

    target_include_directories(
        butterscotch
        SYSTEM
        PUBLIC
            vendor/miniaudio
    )

    target_include_directories(
        butterscotch
        PUBLIC
            src/audio/miniaudio
    )

    add_compile_definitions(USE_MINIAUDIO)

    if(NOT WIN32 AND NOT APPLE)

        set(AUDIO_LIBRARIES
            pthread
        )

    endif()

elseif(AUDIO_BACKEND STREQUAL "web")

    target_include_directories(
        butterscotch
        SYSTEM
        PUBLIC
            vendor/miniaudio
    )

    target_include_directories(
        butterscotch
        PUBLIC
            src/audio/web
            src/audio/miniaudio
    )

    add_compile_definitions(USE_WEB_AUDIO)

elseif(AUDIO_BACKEND STREQUAL "ps2")

    target_include_directories(
        butterscotch
        PUBLIC
            src/audio/ps2
    )

    add_compile_definitions(USE_PS2_AUDIO)

endif()

# ==============================================================================
# stb_ds
# ==============================================================================

add_library(stb_ds INTERFACE)

target_include_directories(
    stb_ds
    SYSTEM
    INTERFACE
        ${CMAKE_SOURCE_DIR}/vendor/stb/ds
)

# ==============================================================================
# stb_vorbis
# ==============================================================================

add_library(stb_vorbis INTERFACE)

target_include_directories(
    stb_vorbis
    SYSTEM
    INTERFACE
        ${CMAKE_SOURCE_DIR}/vendor/stb/vorbis
)

# ==============================================================================
# MD5
# ==============================================================================

target_sources(
    butterscotch
    PRIVATE
        vendor/md5/md5.c
)

target_include_directories(
    butterscotch
    PUBLIC
        vendor/md5
)

# ==============================================================================
# SHA1
# ==============================================================================

add_library(
    sha1
    STATIC
        vendor/sha1/sha1.c
)

target_include_directories(
    sha1
    SYSTEM
    PUBLIC
        vendor/sha1
)

target_compile_options(
    sha1
    PRIVATE
        -w
)

# ==============================================================================
# Base64
# ==============================================================================

target_sources(
    butterscotch
    PRIVATE
        vendor/base64/base64.c
)

target_include_directories(
    butterscotch
    PUBLIC
        vendor/base64
)

# ==============================================================================
# bzip2
# ==============================================================================

add_library(
    bzip2
    STATIC
        vendor/bzip2/bz_internal_error.c
        vendor/bzip2/bzlib.c
        vendor/bzip2/crctable.c
        vendor/bzip2/decompress.c
        vendor/bzip2/huffman.c
        vendor/bzip2/randtable.c
)

target_include_directories(
    bzip2
    PUBLIC
        vendor/bzip2
)

target_compile_options(
    bzip2
    PRIVATE
        -w
)

# ==============================================================================
# miniz (iOS game ZIP import)
# ==============================================================================

if(BUTTERSCOTCH_PLATFORM STREQUAL "ios")
    if(NOT EXISTS "${CMAKE_SOURCE_DIR}/vendor/miniz/miniz.c")
        message(FATAL_ERROR
            "iOS game import requires vendor/miniz. Clone https://github.com/richgel999/miniz into vendor/miniz.")
    endif()

    add_library(
        miniz
        STATIC
        vendor/miniz/miniz.c
        vendor/miniz/miniz_tdef.c
        vendor/miniz/miniz_tinfl.c
        vendor/miniz/miniz_zip.c
    )

    target_include_directories(
        miniz
        SYSTEM
        PUBLIC
            vendor/miniz
    )
endif()

# ==============================================================================
# Optional logging
# ==============================================================================

option(
    ENABLE_SPATIAL_GRID_LOGS
    "Enable Spatial Grid logs"
    OFF
)

if(ENABLE_SPATIAL_GRID_LOGS)
    add_compile_definitions(ENABLE_SPATIAL_GRID_LOGS)
endif()

option(
    ENABLE_VM_EXCEPTIONS_LOGS
    "Enable VM Exceptions logs"
    OFF
)

if(ENABLE_VM_EXCEPTIONS_LOGS)
    add_compile_definitions(ENABLE_VM_EXCEPTIONS_LOGS)
endif()

# ==============================================================================
# CLI / Vita / iOS renderer and backend
# ==============================================================================

if(BUTTERSCOTCH_PLATFORM STREQUAL "cli"
   OR BUTTERSCOTCH_PLATFORM STREQUAL "vita"
   OR BUTTERSCOTCH_PLATFORM STREQUAL "ios")

    # --------------------------------------------------------------------------
    # Platform defaults
    # --------------------------------------------------------------------------

    if(BUTTERSCOTCH_PLATFORM STREQUAL "vita")

        add_compile_definitions(
            __VITA__
            BUTTERSCOTCH_PLATFORM_VITA
        )

        set(VM_GML_PROFILER_DEFAULT OFF)
        set(VM_TRACING_DEFAULT OFF)
        set(VM_OPCODE_PROFILER_DEFAULT OFF)
        set(VM_STUB_LOGS_DEFAULT OFF)

    elseif(BUTTERSCOTCH_PLATFORM STREQUAL "ios")

        # iOS should behave more like a mobile target than desktop CLI.
        set(VM_GML_PROFILER_DEFAULT OFF)
        set(VM_TRACING_DEFAULT OFF)
        set(VM_OPCODE_PROFILER_DEFAULT OFF)
        set(VM_STUB_LOGS_DEFAULT OFF)

        add_compile_definitions(
            BUTTERSCOTCH_PLATFORM_IOS
            ENABLE_GLES
        )

    else()

        set(VM_GML_PROFILER_DEFAULT ON)
        set(VM_TRACING_DEFAULT ON)
        set(VM_OPCODE_PROFILER_DEFAULT ON)
        set(VM_STUB_LOGS_DEFAULT ON)

    endif()

    # --------------------------------------------------------------------------
    # FORTIFY
    # --------------------------------------------------------------------------

    if(NOT BUTTERSCOTCH_PLATFORM STREQUAL "ios")
        target_compile_options(
            butterscotch
            PRIVATE
                "$<$<CONFIG:Release,RelWithDebInfo>:-U_FORTIFY_SOURCE;-D_FORTIFY_SOURCE=2>"
        )
    endif()

    # --------------------------------------------------------------------------
    # Renderer
    # --------------------------------------------------------------------------

    if(NOT ENABLE_LEGACY_GL AND NOT ENABLE_MODERN_GL
    AND NOT BUTTERSCOTCH_PLATFORM STREQUAL "ios")

        message(FATAL_ERROR
            "You must enable at least one renderer!")

    endif()


    # iOS is GLES/modern-only.
    if(BUTTERSCOTCH_PLATFORM STREQUAL "ios"
       AND ENABLE_LEGACY_GL)

        message(FATAL_ERROR
            "The legacy OpenGL renderer cannot be enabled on iOS.")

    endif()

    file(GLOB GL_SOURCES
        src/image/*.c
        src/gl_common/*.c
    )

    if(ENABLE_LEGACY_GL)

        file(GLOB GL_SOURCES
            ${GL_SOURCES}
            src/gl_legacy/*.c
        )

        target_include_directories(
            butterscotch
            PRIVATE
                ${CMAKE_SOURCE_DIR}/src/gl_legacy
        )

    endif()

    if(ENABLE_MODERN_GL)

        file(GLOB GL_SOURCES
            ${GL_SOURCES}
            src/gl/*.c
        )

    endif()

    target_sources(
        butterscotch
        PRIVATE
            ${GL_SOURCES}
    )

    target_include_directories(
        butterscotch
        PRIVATE
            ${CMAKE_SOURCE_DIR}/src/gl
            ${CMAKE_SOURCE_DIR}/src/gl_common
            ${CMAKE_SOURCE_DIR}/src/image
    )

    # --------------------------------------------------------------------------
    # iOS GLES headers
    # --------------------------------------------------------------------------

    if(BUTTERSCOTCH_PLATFORM STREQUAL "ios")

        target_include_directories(
            butterscotch
            PRIVATE
                ${CMAKE_OSX_SYSROOT}/System/Library/Frameworks/OpenGLES.framework/Headers
        )

        set_target_properties(
            butterscotch
            PROPERTIES
                SWIFT_VERSION 5.0
                XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER
                    "${CMAKE_SOURCE_DIR}/src/ios/Butterscotch-Bridging-Header.h"
        )
    endif()

    # --------------------------------------------------------------------------
    # MSVC compatibility
    # --------------------------------------------------------------------------

    if(MSVC)

        target_include_directories(
            butterscotch
            PRIVATE
                ${CMAKE_SOURCE_DIR}/compat/getopt
        )

        add_compile_definitions(
            NO_STRTOK_R
            NO_STRCASECMP
        )

    endif()

    # --------------------------------------------------------------------------
    # VM profiler
    # --------------------------------------------------------------------------

    option(
        ENABLE_VM_GML_PROFILER
        "Enable Butterscotch VM/interpreter profiler"
        ${VM_GML_PROFILER_DEFAULT}
    )

    if(ENABLE_VM_GML_PROFILER)
        add_compile_definitions(ENABLE_VM_GML_PROFILER)
    endif()

    # --------------------------------------------------------------------------
    # VM tracing
    # --------------------------------------------------------------------------

    option(
        ENABLE_VM_TRACING
        "Enable Butterscotch VM/interpreter tracing checks"
        ${VM_TRACING_DEFAULT}
    )

    if(ENABLE_VM_TRACING)
        add_compile_definitions(ENABLE_VM_TRACING)
    endif()

    # --------------------------------------------------------------------------
    # VM opcode profiler
    # --------------------------------------------------------------------------

    option(
        ENABLE_VM_OPCODE_PROFILER
        "Enable Butterscotch VM opcode count profiler"
        ${VM_OPCODE_PROFILER_DEFAULT}
    )

    if(ENABLE_VM_OPCODE_PROFILER)
        add_compile_definitions(ENABLE_VM_OPCODE_PROFILER)
    endif()

    # --------------------------------------------------------------------------
    # VM stub logs
    # --------------------------------------------------------------------------

    option(
        ENABLE_VM_STUB_LOGS
        "Enable VM unknown/stubbed function logs"
        ${VM_STUB_LOGS_DEFAULT}
    )

    if(ENABLE_VM_STUB_LOGS)
        add_compile_definitions(ENABLE_VM_STUB_LOGS)
    endif()

    # --------------------------------------------------------------------------
    # stb_image
    # --------------------------------------------------------------------------

    target_include_directories(
        butterscotch
        PUBLIC
            vendor/stb/image
    )

    # --------------------------------------------------------------------------
    # Platform libraries
    # --------------------------------------------------------------------------

    set(BUTTERSCOTCH_PLATFORM_LIBRARIES
        bzip2
        stb_ds
        sha1
        stb_vorbis
    )

    # GLAD is for desktop OpenGL.
    #
    # IMPORTANT:
    # Do NOT build/link GLAD on iOS. The iOS renderer uses Apple's OpenGLES
    # framework directly.
    if(NOT BUTTERSCOTCH_PLATFORM STREQUAL "vita"
       AND NOT BUTTERSCOTCH_PLATFORM STREQUAL "ios")

        add_library(
            glad
            STATIC
                vendor/glad/src/glad.c
        )

        target_include_directories(
            glad
            PUBLIC
                vendor/glad/include
        )

        target_compile_options(
            glad
            PRIVATE
                -Wno-unused-but-set-variable
        )

        list(APPEND
            BUTTERSCOTCH_PLATFORM_LIBRARIES
            glad
        )

    endif()

    # --------------------------------------------------------------------------
    # Math / dynamic loader
    # --------------------------------------------------------------------------

    if(NOT MSVC AND NOT APPLE)
        list(APPEND
            BUTTERSCOTCH_PLATFORM_LIBRARIES
            m
        )
    endif()

    if(WIN32)

        list(APPEND
            BUTTERSCOTCH_PLATFORM_LIBRARIES
            opengl32
            gdi32
            winmm
        )

    elseif(NOT BUTTERSCOTCH_PLATFORM STREQUAL "vita"
           AND NOT BUTTERSCOTCH_PLATFORM STREQUAL "ios"
           AND NOT APPLE)

        list(APPEND
            BUTTERSCOTCH_PLATFORM_LIBRARIES
            ${CMAKE_DL_LIBS}
        )

    endif()

    # --------------------------------------------------------------------------
    # Backend
    # --------------------------------------------------------------------------

    if(BACKEND STREQUAL "glfw3")

        add_compile_definitions(USE_GLFW3)

        if(MINGW)

            find_package(glfw3 CONFIG REQUIRED)

            target_compile_definitions(
                butterscotch
                PRIVATE
                    _WIN32_WINNT=0x0601
                    NTDDI_VERSION=0x06010000
                    WIN32_LEAN_AND_MEAN
            )

            target_link_options(
                butterscotch
                PRIVATE
                    -static
            )

            set(BACKEND_LIBRARIES
                glfw
                opengl32
                gdi32
                winmm
            )

        elseif(MSVC)

            target_compile_definitions(
                butterscotch
                PRIVATE
                    WIN32_LEAN_AND_MEAN
                    _CRT_SECURE_NO_WARNINGS
            )

            find_package(glfw3 CONFIG REQUIRED)

            set(BACKEND_LIBRARIES
                glfw
                opengl32
                gdi32
                winmm
            )

        else()

            find_package(PkgConfig REQUIRED)

            pkg_check_modules(
                GLFW3
                REQUIRED
                glfw3
            )

            target_include_directories(
                butterscotch
                PRIVATE
                    ${GLFW3_INCLUDE_DIRS}
            )

            target_link_directories(
                butterscotch
                PRIVATE
                    ${GLFW3_LIBRARY_DIRS}
            )

            set(BACKEND_LIBRARIES
                ${GLFW3_LIBRARIES}
            )

        endif()

    elseif(BACKEND STREQUAL "glfw2")

        add_compile_definitions(USE_GLFW2)

        find_package(PkgConfig REQUIRED)

        pkg_check_modules(
            GLFW2
            REQUIRED
            libglfw
        )

        target_include_directories(
            butterscotch
            PRIVATE
                ${GLFW2_INCLUDE_DIRS}
        )

        target_link_directories(
            butterscotch
            PRIVATE
                ${GLFW2_LIBRARY_DIRS}
        )

        set(BACKEND_LIBRARIES
            ${GLFW2_LIBRARIES}
        )

    elseif(BACKEND STREQUAL "sdl1")

        add_compile_definitions(USE_SDL1)

        find_package(SDL REQUIRED)

        target_include_directories(
            butterscotch
            PUBLIC
                ${SDL_INCLUDE_DIR}
        )

        set(BACKEND_LIBRARIES
            ${SDL_LIBRARY}
        )

    elseif(BACKEND STREQUAL "sdl2")

        add_compile_definitions(USE_SDL2)

        # Build the vendored SDL2 using the same iOS toolchain/sysroot/
        # architecture as Butterscotch.
        add_subdirectory(
            vendor/SDL2
            ${CMAKE_BINARY_DIR}/SDL2
        )

        target_include_directories(
            butterscotch
            PRIVATE
                ${SDL2_INCLUDE_DIRS}
        )

        # SDL2's CMake target is preferable to manually constructing paths.
        #
        # SDL2-static is what your existing project uses. SDL2main contains
        # SDL's platform-specific main() handling.
        set(BACKEND_LIBRARIES
            SDL2-static
        #   SDL2main
        )

        if(TARGET sdl_headers_copy)
            add_dependencies(
                butterscotch
                sdl_headers_copy
            )
        endif()

    elseif(BACKEND STREQUAL "sdl3")

        add_compile_definitions(USE_SDL3)

        find_package(PkgConfig REQUIRED)

        pkg_check_modules(
            SDL3
            REQUIRED
            sdl3
        )

        target_include_directories(
            butterscotch
            PRIVATE
                ${SDL3_INCLUDE_DIRS}
        )

        target_link_directories(
            butterscotch
            PRIVATE
                ${SDL3_LIBRARY_DIRS}
        )

        set(BACKEND_LIBRARIES
            ${SDL3_LIBRARIES}
        )

    elseif(BACKEND STREQUAL "appkit")

        add_compile_definitions(USE_APPKIT)

        target_compile_definitions(
            butterscotch
            PRIVATE
                GL_SILENCE_DEPRECATION
        )

        set(BACKEND_LIBRARIES
            "-framework Cocoa"
            "-framework GameController"
        )

    else()

        message(FATAL_ERROR
            "Unknown backend '${BACKEND}'")

    endif()

    # --------------------------------------------------------------------------
    # iOS-specific backend configuration
    # --------------------------------------------------------------------------

    if(BUTTERSCOTCH_PLATFORM STREQUAL "ios")
        # Games are imported by the UIKit launcher into Application Support.
        # Do not ship game data in the application bundle.



        if(NOT BACKEND STREQUAL "sdl2")
            message(FATAL_ERROR
                "iOS requires the SDL2 backend.")
        endif()

        # SDL's UIKit backend is Objective-C.
        #
        # project() already enables OBJC, so SDL's .m files can be compiled
        # correctly when its iOS sources are selected.
        set_target_properties(
            butterscotch
            PROPERTIES
                MACOSX_BUNDLE TRUE

                MACOSX_BUNDLE_INFO_PLIST
                    "${CMAKE_SOURCE_DIR}/src/ios/Info.plist.in"

                XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME
                    "AppIcon"

                SWIFT_VERSION
                    5.0

                XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER
                    "${CMAKE_SOURCE_DIR}/src/ios/Butterscotch-Bridging-Header.h"
        )

        # iOS application bundle metadata.
        set_target_properties(
            butterscotch
            PROPERTIES
                MACOSX_BUNDLE_GUI_IDENTIFIER
                    "com.butterscotch.butterscotch"
                MACOSX_BUNDLE_BUNDLE_NAME
                    "Butterscotch"
                MACOSX_BUNDLE_BUNDLE_VERSION
                    "1"
                MACOSX_BUNDLE_SHORT_VERSION_STRING
                    "1.0"
        )

        # Use Apple's GLES implementation.
        list(APPEND
            BACKEND_LIBRARIES
            ${IOS_SYSTEM_LIBRARIES}
        )

        list(APPEND BACKEND_LIBRARIES miniz)

        # iOS has no desktop OpenGL library and must not link GLAD.
        #
        # These definitions allow the renderer to select the GLES code path.
        target_compile_definitions(
            butterscotch
            PRIVATE
                ENABLE_GLES
                BUTTERSCOTCH_PLATFORM_IOS
                GL_GLEXT_PROTOTYPES=1
        )

    endif()

    # --------------------------------------------------------------------------
    # Link
    # --------------------------------------------------------------------------

    if(BUTTERSCOTCH_PLATFORM STREQUAL "vita")

        target_link_libraries(
            butterscotch
            PRIVATE
                ${BACKEND_LIBRARIES}
                ${AUDIO_LIBRARIES}
                ${BUTTERSCOTCH_PLATFORM_LIBRARIES}
                vitaGL
                stdc++
                SceShaccCgExt
                taihen_stub
                SceShaccCg_stub
        )

        vita_create_self(
            eboot.bin
            butterscotch
            UNSAFE
        )

        vita_create_vpk(
            Butterscotch.vpk
            ${VITA_TITLEID}
            eboot.bin
            VERSION ${VITA_VERSION}
            NAME ${VITA_APP_NAME}
        )

    elseif(BUTTERSCOTCH_PLATFORM STREQUAL "ios")

        target_link_libraries(
            butterscotch
            PRIVATE
                ${BACKEND_LIBRARIES}
                ${AUDIO_LIBRARIES}
                ${BUTTERSCOTCH_PLATFORM_LIBRARIES}
                miniz
                ${IOS_OPENGLES_FRAMEWORK}
                ${IOS_UIKIT_FRAMEWORK}
                ${IOS_FOUNDATION_FRAMEWORK}
                ${IOS_PHOTOS_FRAMEWORK}
                ${IOS_PHOTOSUI_FRAMEWORK}
                ${IOS_UNIFORMTYPEIDENTIFIERS_FRAMEWORK}
        )

        if(IOS_GAMECONTROLLER_FRAMEWORK)
            target_link_libraries(
                butterscotch
                PRIVATE
                    ${IOS_GAMECONTROLLER_FRAMEWORK}
            )
        endif()

    else()

        target_link_libraries(
            butterscotch
            PRIVATE
                ${BACKEND_LIBRARIES}
                ${AUDIO_LIBRARIES}
                ${BUTTERSCOTCH_PLATFORM_LIBRARIES}
        )

    endif()

    # --------------------------------------------------------------------------
    # Backend source
    # --------------------------------------------------------------------------

    if(BACKEND STREQUAL "appkit")

        target_sources(
            butterscotch
            PRIVATE
                src/backends/${BACKEND}.m
        )

    else()

        target_sources(
            butterscotch
            PRIVATE
                src/backends/${BACKEND}.c
        )

    endif()

    # --------------------------------------------------------------------------
    # AddressSanitizer
    # --------------------------------------------------------------------------

    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(ENABLE_ASAN_DEFAULT ON)
    else()
        set(ENABLE_ASAN_DEFAULT OFF)
    endif()

    # Disable ASan by default for iOS.
    # Simulator ASan can be enabled later if desired, but don't inject
    # sanitizer flags into the normal iOS build.
    if(BUTTERSCOTCH_PLATFORM STREQUAL "ios")
        set(ENABLE_ASAN_DEFAULT OFF)
    endif()

    set(
        ENABLE_ASAN
        ${ENABLE_ASAN_DEFAULT}
        CACHE BOOL
        "Enable AddressSanitizer"
    )

    if(ENABLE_ASAN
       AND NOT WIN32
       AND NOT CMAKE_SYSTEM_NAME STREQUAL "Haiku"
       AND NOT BUTTERSCOTCH_PLATFORM STREQUAL "ios")

        target_compile_options(
            butterscotch
            PRIVATE
                -fsanitize=address
                -fno-omit-frame-pointer
        )

        target_link_options(
            butterscotch
            PRIVATE
                -fsanitize=address
        )

    endif()

    # --------------------------------------------------------------------------
    # gamecontrollerdb
    # --------------------------------------------------------------------------

    if(NOT BUTTERSCOTCH_PLATFORM STREQUAL "ios")

        add_custom_command(
            TARGET butterscotch
            POST_BUILD

            COMMAND
                ${CMAKE_COMMAND}
                -E
                copy_if_different
                ${CMAKE_SOURCE_DIR}/vendor/gamecontrollerdb.txt
                $<TARGET_FILE_DIR:butterscotch>/gamecontrollerdb.txt
        )

    endif()

# ==============================================================================
# Web
# ==============================================================================

elseif(BUTTERSCOTCH_PLATFORM STREQUAL "web")

    if(NOT ENABLE_MODERN_GL)
        message(FATAL_ERROR
            "Web requires modern GL!")
    endif()

    file(GLOB GL_SOURCES
        src/gl/*.c
        src/gl_common/*.c
        src/image/*.c
    )

    target_sources(
        butterscotch
        PRIVATE
            ${GL_SOURCES}
    )

    target_include_directories(
        butterscotch
        PRIVATE
            ${CMAKE_SOURCE_DIR}/src/gl
            ${CMAKE_SOURCE_DIR}/src/gl_common
            ${CMAKE_SOURCE_DIR}/src/image
    )

    target_include_directories(
        butterscotch
        PUBLIC
            vendor/stb/image
    )

    target_link_libraries(
        butterscotch
        PRIVATE
            bzip2
            stb_ds
            sha1
            stb_vorbis
    )

    set_target_properties(
        butterscotch
        PROPERTIES
            SUFFIX ".mjs"
    )

    target_link_options(
        butterscotch
        PRIVATE
            "-sMODULARIZE=1"
            "-sEXPORT_ES6=1"
            "-sENVIRONMENT=worker"
            "-sWASMFS=1"
            "-sEXPORTED_RUNTIME_METHODS=['HEAP8', 'HEAPU8', 'HEAPF32', 'ccall', 'cwrap', 'specialHTMLTargets', 'UTF8ToString']"
            "-sEXPORTED_FUNCTIONS=['_main', '_mountOpfs', '_startRunner', '_stopRunner', '_malloc', '_free', '_getKeyDownPtr', '_getKeyUpPtr', '_getKeyCount', '_setAudioSampleRate', '_pullAudioFrames']"
            "-sOFFSCREENCANVAS_SUPPORT=1"
            "-sOFFSCREEN_FRAMEBUFFER=1"
            "-sMIN_WEBGL_VERSION=2"
            "-sMAX_WEBGL_VERSION=2"
            "-sFULL_ES3=1"
            "-sALLOW_MEMORY_GROWTH"
            "-sSHARED_MEMORY=1"
            "-sPTHREAD_POOL_SIZE=4"
            "-pthread"
    )

    target_compile_options(
        butterscotch
        PRIVATE
            "-pthread"
    )

# ==============================================================================
# Web metadata
# ==============================================================================

elseif(BUTTERSCOTCH_PLATFORM STREQUAL "web-meta")

    set_target_properties(
        butterscotch
        PROPERTIES
            SUFFIX ".mjs"
            OUTPUT_NAME "butterscotch-meta"
    )

    target_link_libraries(
        butterscotch
        PRIVATE
            stb_ds
    )

    target_link_options(
        butterscotch
        PRIVATE
            "-sMODULARIZE=1"
            "-sEXPORT_ES6=1"
            "-sENVIRONMENT=web"
            "-sEXPORTED_RUNTIME_METHODS=['HEAPU8', 'ccall', 'cwrap', 'UTF8ToString', 'FS']"
            "-sEXPORTED_FUNCTIONS=['_main', '_parseDataWin', '_freeDataWin', '_getGameName', '_getGameDisplayName', '_getMajorVersion', '_getMinorVersion', '_getRelease', '_getBuild', '_getDefaultWindowWidth', '_getDefaultWindowHeight', '_malloc', '_free']"
            "-sALLOW_MEMORY_GROWTH=1"
            "-sFORCE_FILESYSTEM=1"
    )

# ==============================================================================
# Android
# ==============================================================================

elseif(BUTTERSCOTCH_PLATFORM STREQUAL "android")

    if(NOT ENABLE_MODERN_GL)
        message(FATAL_ERROR
            "Android requires modern GL!")
    endif()

    file(GLOB GL_SOURCES
        src/gl/*.c
        src/gl_common/*.c
        src/image/*.c
    )

    target_sources(
        butterscotch
        PRIVATE
            ${GL_SOURCES}
    )

    target_include_directories(
        butterscotch
        PRIVATE
            ${CMAKE_SOURCE_DIR}/src/gl
            ${CMAKE_SOURCE_DIR}/src/gl_common
            ${CMAKE_SOURCE_DIR}/src/image
    )

    add_compile_definitions(
        ENABLE_GLES
        BUTTERSCOTCH_PLATFORM_ANDROID
    )

    option(
        ENABLE_VM_GML_PROFILER
        "Enable Butterscotch VM/interpreter profiler"
        ON
    )

    if(ENABLE_VM_GML_PROFILER)
        add_compile_definitions(ENABLE_VM_GML_PROFILER)
    endif()

    option(
        ENABLE_VM_TRACING
        "Enable Butterscotch VM/interpreter tracing checks"
        ON
    )

    if(ENABLE_VM_TRACING)
        add_compile_definitions(ENABLE_VM_TRACING)
    endif()

    option(
        ENABLE_VM_OPCODE_PROFILER
        "Enable Butterscotch VM opcode count profiler"
        OFF
    )

    if(ENABLE_VM_OPCODE_PROFILER)
        add_compile_definitions(ENABLE_VM_OPCODE_PROFILER)
    endif()

    option(
        ENABLE_VM_STUB_LOGS
        "Enable VM unknown/stubbed function logs"
        ON
    )

    if(ENABLE_VM_STUB_LOGS)
        add_compile_definitions(ENABLE_VM_STUB_LOGS)
    endif()

    target_include_directories(
        butterscotch
        PUBLIC
            vendor/stb/image
            vendor/stb/vorbis
    )

    target_link_libraries(
        butterscotch
        PRIVATE
            log
            GLESv3
            OpenSLES
            bzip2
            stb_ds
            sha1
            stb_vorbis
    )

# ==============================================================================
# PS2
# ==============================================================================

elseif(BUTTERSCOTCH_PLATFORM STREQUAL "ps2")

    file(GLOB DEBUG_FONT_SOURCES
        src/debug_font/*.c
    )

    target_sources(
        butterscotch
        PRIVATE
            ${DEBUG_FONT_SOURCES}
    )

    target_include_directories(
        butterscotch
        PRIVATE
            ${CMAKE_SOURCE_DIR}/src/debug_font
    )

    add_compile_definitions(
        USE_FLOAT_REALS
        NO_RVALUE_INT64
        BUTTERSCOTCH_PLATFORM_PS2
    )

    option(
        ENABLE_VM_GML_PROFILER
        "Enable Butterscotch VM/interpreter profiler"
        OFF
    )

    if(ENABLE_VM_GML_PROFILER)
        add_compile_definitions(ENABLE_VM_GML_PROFILER)
    endif()

    option(
        ENABLE_VM_TRACING
        "Enable Butterscotch VM/interpreter tracing checks"
        OFF
    )

    if(ENABLE_VM_TRACING)
        add_compile_definitions(ENABLE_VM_TRACING)
    endif()

    option(
        ENABLE_VM_OPCODE_PROFILER
        "Enable Butterscotch VM opcode count profiler"
        OFF
    )

    if(ENABLE_VM_OPCODE_PROFILER)
        add_compile_definitions(ENABLE_VM_OPCODE_PROFILER)
    endif()

    option(
        ENABLE_SPATIAL_GRID_LOGS
        "Enable Spatial Grid logs"
        OFF
    )

    if(ENABLE_SPATIAL_GRID_LOGS)
        add_compile_definitions(ENABLE_SPATIAL_GRID_LOGS)
    endif()

    option(
        ENABLE_VM_STUB_LOGS
        "Enable VM unknown/stubbed function logs"
        OFF
    )

    if(ENABLE_VM_STUB_LOGS)
        add_compile_definitions(ENABLE_VM_STUB_LOGS)
    endif()

    option(
        ENABLE_PS2_RENDERER_LOGS
        "Enable hot path logs in the PS2 renderer"
        OFF
    )

    if(ENABLE_PS2_RENDERER_LOGS)
        add_compile_definitions(ENABLE_PS2_RENDERER_LOGS)
    endif()

    target_compile_options(
        butterscotch
        PRIVATE
            -fsingle-precision-constant
            -Werror=double-promotion
            -Wno-format
    )

    if(PS2)

        target_include_directories(
            butterscotch
            PRIVATE
                $ENV{PS2SDK}/ee/include
                $ENV{PS2SDK}/common/include
                $ENV{PS2DEV}/ee/include
                $ENV{GSKIT}/include
        )

        target_link_directories(
            butterscotch
            PRIVATE
                $ENV{PS2SDK}/ee/lib
                $ENV{GSKIT}/lib
        )

        target_link_libraries(
            butterscotch
            PRIVATE
                gskit
                dmakit
                audsrv
                pad
                mc
                kbd
                patches
                kernel
                c
                m
                stb_ds
                sha1
        )

        set(IRX_DIR
            $ENV{PS2SDK}/iop/irx
        )

        set(IRX_GEN_DIR
            ${CMAKE_BINARY_DIR}/generated/irx
        )

        file(MAKE_DIRECTORY
            ${IRX_GEN_DIR}
        )

        foreach(IRX_NAME
            freesio2
            mcman
            mcserv
            freepad
            usbd
            ps2kbd
        )

            add_custom_command(
                OUTPUT
                    ${IRX_GEN_DIR}/${IRX_NAME}_irx.c

                COMMAND
                    $ENV{PS2SDK}/bin/bin2c
                    ${IRX_DIR}/${IRX_NAME}.irx
                    ${IRX_GEN_DIR}/${IRX_NAME}_irx.c
                    ${IRX_NAME}_irx

                DEPENDS
                    ${IRX_DIR}/${IRX_NAME}.irx

                COMMENT
                    "Embedding ${IRX_NAME}.irx"
            )

            target_sources(
                butterscotch
                PRIVATE
                    ${IRX_GEN_DIR}/${IRX_NAME}_irx.c
            )

        endforeach()

        target_include_directories(
            butterscotch
            PRIVATE
                ${IRX_GEN_DIR}
        )

    else()

        file(GLOB PS2SDK_EE_INCLUDES
            ${CMAKE_SOURCE_DIR}/ps2sdk/ee/*/include
        )

        file(GLOB PS2SDK_EE_RPC_INCLUDES
            ${CMAKE_SOURCE_DIR}/ps2sdk/ee/rpc/*/include
        )

        file(GLOB PS2SDK_EE_NETWORK_INCLUDES
            ${CMAKE_SOURCE_DIR}/ps2sdk/ee/network/*/include
        )

        file(GLOB GSKIT_INCLUDES
            ${CMAKE_SOURCE_DIR}/gsKit/ee/*/include
        )

        target_compile_definitions(
            butterscotch
            PRIVATE
                _EE
        )

        target_include_directories(
            butterscotch
            PRIVATE
                ${PS2SDK_EE_INCLUDES}
                ${PS2SDK_EE_RPC_INCLUDES}
                ${PS2SDK_EE_NETWORK_INCLUDES}
                ${CMAKE_SOURCE_DIR}/ps2sdk/common/include
                ${GSKIT_INCLUDES}
                ${CMAKE_SOURCE_DIR}/ps2dev-headers/newlib-include
                ${CMAKE_SOURCE_DIR}/ps2dev-headers/gcc-include
        )

    endif()

# ==============================================================================
# PS3
# ==============================================================================

elseif(BUTTERSCOTCH_PLATFORM STREQUAL "ps3")

    if(NOT ENABLE_LEGACY_GL)
        message(FATAL_ERROR
            "PS3 requires legacy gl!")
    endif()

    file(GLOB GL_SOURCES
        src/gl_common/*.c
        src/gl_legacy/*.c
        src/image/*.c
    )

    file(GLOB DEBUG_FONT_SOURCES
        src/debug_font/*.c
    )

    target_sources(
        butterscotch
        PRIVATE
            ${GL_SOURCES}
            ${DEBUG_FONT_SOURCES}
    )

    target_include_directories(
        butterscotch
        PRIVATE
            ${CMAKE_SOURCE_DIR}/src/gl_legacy
            ${CMAKE_SOURCE_DIR}/src/image
            ${CMAKE_SOURCE_DIR}/src/debug_font
            ${CMAKE_SOURCE_DIR}/src/gl_common
    )

    file(GLOB PS3GL_SOURCES
        vendor/ps3gl/*.c
    )

    add_library(
        ps3gl
        STATIC
            ${PS3GL_SOURCES}
    )

    target_include_directories(
        ps3gl
        SYSTEM
        PUBLIC
            vendor/ps3gl
    )

    target_compile_options(
        ps3gl
        PRIVATE
            -w
    )

    add_library(
        mojoal
        STATIC
            vendor/mojoal/mojoal.c
    )

    target_include_directories(
        mojoal
        SYSTEM
        PUBLIC
            vendor/mojoal
    )

    target_compile_definitions(
        mojoal
        PRIVATE
            AL_LIBTYPE_STATIC
    )

    target_compile_options(
        mojoal
        PRIVATE
            -w
    )

    add_compile_definitions(
        BUTTERSCOTCH_PLATFORM_PS3
        AL_LIBTYPE_STATIC
    )

    set(
        CMAKE_EXE_LINKER_FLAGS
        "-mhard-float -fmodulo-sched -Wl,--gc-sections -L$ENV{PS3DEV}/ppu/lib -L$ENV{PS3DEV}/portlibs/ppu/lib"
    )

    add_subdirectory(vendor/SDL2)

    target_include_directories(
        butterscotch
        PRIVATE
            ${SDL2_INCLUDE_DIRS}
    )

    target_link_libraries(
        mojoal
        PUBLIC
            ${SDL2_LIBRARIES}
    )

    target_link_libraries(
        butterscotch
        PRIVATE
            bzip2
            sha1
            ps3gl
            mojoal
            ${SDL2_LIBRARIES}
            gcm_sys
            rsx
            sysutil
            io
            audio
            rt
            lv2
            m
            stb_ds
            stb_vorbis
    )

# ==============================================================================
# Unknown platform
# ==============================================================================

else()

    message(FATAL_ERROR
        "Unknown BUTTERSCOTCH_PLATFORM! ${BUTTERSCOTCH_PLATFORM}")

endif()

# ==============================================================================
# iOS final diagnostics
# ==============================================================================

if(BUTTERSCOTCH_PLATFORM STREQUAL "ios")

    message(STATUS "")
    message(STATUS "==============================================")
    message(STATUS " Butterscotch iOS configuration")
    message(STATUS "==============================================")
    message(STATUS " Architecture : ${CMAKE_OSX_ARCHITECTURES}")
    message(STATUS " Sysroot      : ${CMAKE_OSX_SYSROOT}")
    message(STATUS " Deployment   : ${CMAKE_OSX_DEPLOYMENT_TARGET}")
    message(STATUS " Backend      : ${BACKEND}")
    message(STATUS " Audio        : ${AUDIO_BACKEND}")
    message(STATUS " GLES         : ENABLE_GLES")
    message(STATUS " Legacy GL    : ${ENABLE_LEGACY_GL}")
    message(STATUS " Modern GL    : ${ENABLE_MODERN_GL}")
    message(STATUS "==============================================")
    message(STATUS "")

endif()


# ==============================================================================
# iOS asset catalog
# ==============================================================================

if(BUTTERSCOTCH_PLATFORM STREQUAL "ios")

    set(IOS_ASSET_CATALOG
        "${CMAKE_BINARY_DIR}/ButterscotchAssets.xcassets"
    )

    set(IOS_APP_ICON_SET
        "${IOS_ASSET_CATALOG}/AppIcon.appiconset"
    )

    set(IOS_ICON_SET
        "${IOS_ASSET_CATALOG}/icon.imageset"
    )

    file(MAKE_DIRECTORY
        "${IOS_APP_ICON_SET}"
        "${IOS_ICON_SET}"
    )

    # App icon
    configure_file(
        "${CMAKE_SOURCE_DIR}/res/logo.png"
        "${IOS_APP_ICON_SET}/logo.png"
        COPYONLY
    )

    file(WRITE
        "${IOS_APP_ICON_SET}/Contents.json"
        [=[
{
  "images" : [
    {
      "filename" : "logo.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
]=]
    )

    # Image available to Swift / SwiftUI as Image("icon")
    configure_file(
        "${CMAKE_SOURCE_DIR}/res/icon.png"
        "${IOS_ICON_SET}/icon.png"
        COPYONLY
    )

    file(WRITE
        "${IOS_ICON_SET}/Contents.json"
        [=[
{
  "images" : [
    {
      "filename" : "icon.png",
      "idiom" : "universal",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
]=]
    )

    # Tell Xcode that this is a resource.
    target_sources(
        butterscotch
        PRIVATE
            "${IOS_ASSET_CATALOG}"
    )

    set_source_files_properties(
        "${IOS_ASSET_CATALOG}"
        PROPERTIES
            MACOSX_PACKAGE_LOCATION "Resources"
    )

endif()