import SwiftUI
import UniformTypeIdentifiers

private extension UTType {
    static let xdelta = UTType(
        filenameExtension: "zip"
    ) ?? .data
}

struct ModsView: View {

    @ObservedObject
    private var store = GameStore.shared

    @State private var showingImporter = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if store.mods.isEmpty {
                    Text("No mods installed")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.mods) { mod in
                        HStack {
                            Image(systemName: "shippingbox")

                            VStack(alignment: .leading) {
                                Text(mod.name)
                                    .font(.headline)

                                Text(mod.fileRel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .onDelete(perform: deleteMods)
                }
            }
            .navigationTitle("Mods")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [
                    .xdelta
                ],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert(
                "Import Failed",
                isPresented: Binding(
                    get: {
                        errorMessage != nil
                    },
                    set: {
                        if !$0 {
                            errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: Import

    private func handleImport(
        _ result: Result<[URL], Error>
    ) {
        switch result {

        case .failure(let error):
            errorMessage = error.localizedDescription

        case .success(let urls):

            guard let source = urls.first else {
                return
            }

            importMod(source)
        }
    }

    private func importMod(_ source: URL) {

        let scoped =
            source.startAccessingSecurityScopedResource()

        defer {
            if scoped {
                source.stopAccessingSecurityScopedResource()
            }
        }

        let fileName =
            source.lastPathComponent

        guard fileName
            .lowercased()
            .hasSuffix(".xdelta") else {

            errorMessage =
                "The selected file is not an XDelta mod."

            return
        }

        let identifier =
            UUID().uuidString

        let destination =
            store.modsDirectory
                .appendingPathComponent(
                    "\(identifier).xdelta"
                )

        do {

            try FileManager.default.copyItem(
                at: source,
                to: destination
            )

            let mod = Mod(
                id: identifier,
                name:
                    source
                        .deletingPathExtension()
                        .lastPathComponent,
                fileRel:
                    "\(identifier).xdelta"
            )

            store.add(mod)

        } catch {

            errorMessage =
                "Could not import the mod: \(error.localizedDescription)"
        }
    }

    // MARK: Delete

    private func deleteMods(
        at offsets: IndexSet
    ) {
        for index in offsets {
            store.delete(
                store.mods[index]
            )
        }
    }
}
