import SwiftUI
import UniformTypeIdentifiers

struct SaveBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }

    var fileWrapper: FileWrapper?

    init(directoryWrapper: FileWrapper) {
        self.fileWrapper = directoryWrapper
    }

    init(configuration: ReadConfiguration) throws {
        self.fileWrapper = configuration.file
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let fileWrapper = fileWrapper else {
            throw CocoaError(.fileWriteUnknown)
        }
        return fileWrapper
    }
}
