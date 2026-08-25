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
    @State private var icon: UIImage?

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

        _icon =
            State(
                initialValue:
                    GameStore.shared.icon(
                        for: game
                    )
            )
    }

    var body: some View {

        NavigationStack {

            Form {

                Section("Game") {

                    TextField(
                        "Name",
                        text: $name
                    )

                    TextField(
                        "Description",
                        text: $description,
                        axis: .vertical
                    )
                }

                Section("Icon") {

                    HStack {

                        if let icon {

                            Image(uiImage: icon)
                                .resizable()
                                .scaledToFill()
                                .frame(
                                    width: 64,
                                    height: 64
                                )
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 12
                                    )
                                )

                        } else {

                            Image(
                                systemName:
                                    "photo"
                            )
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                            .frame(
                                width: 64,
                                height: 64
                            )
                        }

                        VStack(
                            alignment: .leading
                        ) {

                            PhotosPicker(
                                selection:
                                    $selectedPhoto,
                                matching: .images
                            ) {
                                Text(
                                    icon == nil
                                        ? "Choose Photo"
                                        : "Change Photo"
                                )
                            }

                            Button(
                                "Choose from Files"
                            ) {
                                showingFilePicker = true
                            }

                            if icon != nil {

                                Button(
                                    "Remove Icon",
                                    role: .destructive
                                ) {
                                    icon = nil
                                }
                            }
                        }
                    }
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
            .onChange(
                of: selectedPhoto
            ) {
                _, newValue in

                loadPhoto(newValue)
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

    private func loadPhoto(
        _ item: PhotosPickerItem?
    ) {

        guard let item else {
            return
        }

        Task {

            if let data =
                try? await item.loadTransferable(
                    type: Data.self
                ),
                let image =
                UIImage(data: data!) {

                await MainActor.run {
                    icon = image
                }
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

        icon = image
    }

    private func save() {

        var game = originalGame

        game.name =
            name.isEmpty
                ? "Imported Game"
                : name

        game.description =
            description

        if let icon {

            let iconRel =
                "\(game.id)/icon.png"

            let iconURL =
                store.gamesDirectory
                    .appendingPathComponent(
                        iconRel
                    )

            return

            game.iconRel = iconRel

        } else {

            if let oldIcon =
                store.iconURL(for: game) {

                try? FileManager.default
                    .removeItem(
                        at: oldIcon
                    )
            }

            game.iconRel = nil
        }

        store.update(game)

        dismiss()
    }
}
