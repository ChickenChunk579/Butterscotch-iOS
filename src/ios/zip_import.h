#ifndef BUTTERSCOTCH_IOS_ZIP_IMPORT_H
#define BUTTERSCOTCH_IOS_ZIP_IMPORT_H

#include <stdbool.h>
#include <stddef.h>

// Extracts a conventional ZIP archive to destinationDirectory. The archive may
// contain data.win at any depth; outDataWinPath receives its extracted path.
// Returns false and writes a human-readable message to error on failure.
bool IOSZipImport_extract(const char *zipPath, const char *destinationDirectory,
                          char *outDataWinPath, size_t outDataWinPathSize,
                          char *error, size_t errorSize);

#endif
