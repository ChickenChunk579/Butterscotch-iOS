#include "zip_import.h"

#include <miniz.h>

#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

#define ZIP_MAX_ENTRIES 4096
#define ZIP_MAX_UNCOMPRESSED (1024ull * 1024ull * 1024ull)

static void setError(char *error, size_t size, const char *format, ...) {
    if (!error || size == 0) return;
    va_list args;
    va_start(args, format);
    vsnprintf(error, size, format, args);
    va_end(args);
}

static bool makeDirectories(const char *path) {
    char copy[4096];
    size_t len = strlen(path);
    if (len == 0 || len >= sizeof(copy)) return false;
    memcpy(copy, path, len + 1);
    for (char *p = copy + 1; *p; ++p) {
        if (*p != '/') continue;
        *p = '\0';
        if (mkdir(copy, 0700) != 0 && errno != EEXIST) return false;
        *p = '/';
    }
    return mkdir(copy, 0700) == 0 || errno == EEXIST;
}

static bool safeArchivePath(const char *path) {
    if (!path[0] || path[0] == '/') return false;
    const char *part = path;
    for (const char *p = path;; ++p) {
        if (*p != '/' && *p != '\0') continue;
        size_t length = (size_t)(p - part);
        if (length == 0 || (length == 1 && part[0] == '.') ||
            (length == 2 && part[0] == '.' && part[1] == '.')) return false;
        if (*p == '\0') return true;
        part = p + 1;
    }
}

bool IOSZipImport_extract(const char *zipPath, const char *destinationDirectory,
                          char *outDataWinPath, size_t outDataWinPathSize,
                          char *error, size_t errorSize) {
    mz_zip_archive archive;
    memset(&archive, 0, sizeof(archive));

    if (!outDataWinPath || outDataWinPathSize == 0) {
        setError(error, errorSize, "Invalid output path buffer.");
        return false;
    }

    outDataWinPath[0] = '\0';

    if (!mz_zip_reader_init_file(&archive, zipPath, 0)) {
        setError(error, errorSize, "This is not a readable ZIP file.");
        return false;
    }

    mz_uint count = mz_zip_reader_get_num_files(&archive);
    if (count == 0 || count > ZIP_MAX_ENTRIES) {
        setError(error, errorSize, "The ZIP has too many files.");
        mz_zip_reader_end(&archive);
        return false;
    }

    if (!makeDirectories(destinationDirectory)) {
        setError(error, errorSize, "Could not create the game library folder.");
        mz_zip_reader_end(&archive);
        return false;
    }

    uint64_t totalSize = 0;

    /*
     * Keep track of the shallowest data.win we've encountered.
     *
     * A root-level:
     *
     *     data.win
     *
     * has depth 0.
     *
     * Whereas:
     *
     *     Game/data.win
     *
     * has depth 1, and:
     *
     *     Game/data/data.win
     *
     * has depth 2.
     */
    bool foundDataWin = false;
    size_t bestDataWinDepth = SIZE_MAX;

    for (mz_uint index = 0; index < count; ++index) {
        mz_zip_archive_file_stat stat;

        if (!mz_zip_reader_file_stat(&archive, index, &stat)) {
            setError(error, errorSize, "Could not inspect a ZIP entry.");
            mz_zip_reader_end(&archive);
            return false;
        }

        if (stat.m_is_directory) continue;

        if (!safeArchivePath(stat.m_filename)) {
            setError(error, errorSize, "The ZIP contains an unsafe file path.");
            mz_zip_reader_end(&archive);
            return false;
        }

        totalSize += stat.m_uncomp_size;

        if (totalSize > ZIP_MAX_UNCOMPRESSED) {
            setError(error, errorSize, "The ZIP expands to more than 1 GB.");
            mz_zip_reader_end(&archive);
            return false;
        }

        char destination[4096];
        char parent[4096];

        if (snprintf(destination, sizeof(destination),
                     "%s/%s",
                     destinationDirectory,
                     stat.m_filename) >= (int)sizeof(destination)) {
            setError(error, errorSize, "A ZIP path is too long.");
            mz_zip_reader_end(&archive);
            return false;
        }

        strncpy(parent, destination, sizeof(parent));
        parent[sizeof(parent) - 1] = '\0';

        char *slash = strrchr(parent, '/');

        if (!slash) {
            setError(error, errorSize, "Invalid ZIP path.");
            mz_zip_reader_end(&archive);
            return false;
        }

        *slash = '\0';

        if (!makeDirectories(parent) ||
            !mz_zip_reader_extract_to_file(
                &archive,
                index,
                destination,
                0)) {
            setError(error, errorSize, "Could not extract a ZIP file.");
            mz_zip_reader_end(&archive);
            return false;
        }

        /*
         * Check whether this is a data.win.
         */
        const char *baseName = strrchr(stat.m_filename, '/');
        baseName = baseName ? baseName + 1 : stat.m_filename;

        if (strcmp(baseName, "data.win") == 0) {

            /*
             * Count the number of directory separators.
             *
             * data.win
             *              -> 0
             *
             * Game/data.win
             *              -> 1
             *
             * Game/data/data.win
             *              -> 2
             */
            size_t depth = 0;

            for (const char *p = stat.m_filename; *p; ++p) {
                if (*p == '/') {
                    ++depth;
                }
            }

            /*
             * Replace the selected data.win whenever this one is
             * closer to the root of the archive.
             *
             * For equal depths, keep the first one encountered.
             * This makes the result deterministic with respect to
             * ZIP entry ordering.
             */
            if (!foundDataWin || depth < bestDataWinDepth) {
                strncpy(
                    outDataWinPath,
                    destination,
                    outDataWinPathSize
                );

                outDataWinPath[outDataWinPathSize - 1] = '\0';

                bestDataWinDepth = depth;
                foundDataWin = true;
            }
        }
    }

    mz_zip_reader_end(&archive);

    if (!foundDataWin) {
        setError(error, errorSize, "No data.win was found in this ZIP.");
        return false;
    }

    return true;
}

bool IOSZipImport_extractDirectory(
    const char *zipPath,
    const char *destinationDirectory,
    char *error,
    size_t errorSize
) {
    mz_zip_archive archive;
    memset(&archive, 0, sizeof(archive));

    if (!mz_zip_reader_init_file(&archive, zipPath, 0)) {
        setError(error, errorSize, "This is not a readable ZIP file.");
        return false;
    }

    mz_uint count = mz_zip_reader_get_num_files(&archive);

    if (count == 0 || count > ZIP_MAX_ENTRIES) {
        setError(error, errorSize, "The ZIP has too many files.");
        mz_zip_reader_end(&archive);
        return false;
    }

    if (!makeDirectories(destinationDirectory)) {
        setError(error, errorSize, "Could not create the destination folder.");
        mz_zip_reader_end(&archive);
        return false;
    }

    uint64_t totalSize = 0;

    for (mz_uint index = 0; index < count; ++index) {

        mz_zip_archive_file_stat stat;

        if (!mz_zip_reader_file_stat(
                &archive,
                index,
                &stat
        )) {
            setError(error, errorSize, "Could not inspect a ZIP entry.");
            mz_zip_reader_end(&archive);
            return false;
        }

        if (stat.m_is_directory) {
            continue;
        }

        if (!safeArchivePath(stat.m_filename)) {
            setError(
                error,
                errorSize,
                "The ZIP contains an unsafe file path."
            );

            mz_zip_reader_end(&archive);
            return false;
        }

        totalSize += stat.m_uncomp_size;

        if (totalSize > ZIP_MAX_UNCOMPRESSED) {
            setError(
                error,
                errorSize,
                "The ZIP expands to more than 1 GB."
            );

            mz_zip_reader_end(&archive);
            return false;
        }

        char destination[4096];

        if (snprintf(
                destination,
                sizeof(destination),
                "%s/%s",
                destinationDirectory,
                stat.m_filename
        ) >= (int)sizeof(destination)) {

            setError(
                error,
                errorSize,
                "A ZIP path is too long."
            );

            mz_zip_reader_end(&archive);
            return false;
        }

        char parent[4096];

        strncpy(
            parent,
            destination,
            sizeof(parent)
        );

        parent[sizeof(parent) - 1] = '\0';

        char *slash = strrchr(parent, '/');

        if (!slash) {
            setError(
                error,
                errorSize,
                "Invalid ZIP path."
            );

            mz_zip_reader_end(&archive);
            return false;
        }

        *slash = '\0';

        if (!makeDirectories(parent)) {
            setError(
                error,
                errorSize,
                "Could not create a save directory."
            );

            mz_zip_reader_end(&archive);
            return false;
        }

        if (!mz_zip_reader_extract_to_file(
                &archive,
                index,
                destination,
                0
        )) {
            setError(
                error,
                errorSize,
                "Could not extract a save file."
            );

            mz_zip_reader_end(&archive);
            return false;
        }
    }

    mz_zip_reader_end(&archive);

    return true;
}