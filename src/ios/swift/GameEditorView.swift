import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct GameEditorView: View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject
    private var store = GameStore.shared

    let originalGame: Game

    @State private var name: String
    @State private var description: String
    @State private var steamAppID: String

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingFilePicker = false

    init(game: Game) {

        self.originalGame = game

        _name =
            State(
                initialValue: game.name
            )

        _description =
            State(
                initialValue: game.description
            )

        _steamAppID =
            State(
                initialValue: game.steamAppID
            )
    }

    var body: some View {

        NavigationStack {

            Form {

                Section("Metadata") {

                    TextField(
                        "Name",
                        text: $name
                    )

                    TextField(
                        "Description",
                        text: $description,
                        axis: .vertical
                    )
                    
                    TextField(
                        "Steam App ID",
                        text: $steamAppID,
                        axis: .vertical
                    )
                }

                
            }
            .navigationTitle(
                originalGame.name.isEmpty
                    ? "Add Game"
                    : "Edit Game"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(
                    placement: .cancellationAction
                ) {

                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement: .confirmationAction
                ) {

                    Button("Save") {
                        save()
                    }
                }
            }
            .fileImporter(
                isPresented:
                    $showingFilePicker,
                allowedContentTypes: [
                    .image
                ],
                allowsMultipleSelection: false
            ) {
                result in

                loadFile(result)
            }
        }
    }

    private func loadFile(
        _ result: Result<[URL], Error>
    ) {

        guard
            case .success(let urls) = result,
            let url = urls.first
        else {
            return
        }

        let scoped =
            url.startAccessingSecurityScopedResource()

        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard
            let data =
                try? Data(contentsOf: url),
            let image =
                UIImage(data: data)
        else {
            return
        }
    }

    private func save() {

        var game = originalGame

        game.name =
            name.isEmpty
                ? "Imported Game"
                : name

        game.description =
            description
        
        game.steamAppID =
            steamAppID

        store.update(game)

        dismiss()
    }
}
