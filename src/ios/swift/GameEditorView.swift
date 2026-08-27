import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Steam App Details Service

/// Fetches game metadata from Steam's public storefront API
/// (https://store.steampowered.com/api/appdetails). This endpoint is
/// free and requires no API key, but it is undocumented/unofficial, so
/// it can occasionally rate-limit or change shape without notice.
enum SteamAppDetailsService {

    struct Details {
        let name: String
        let developers: [String]
        let publishers: [String]
        let shortDescription: String
        let genres: [String]
        let categories: [String]
        let releaseDate: Date?
    }

    enum ServiceError: Error {
        case invalidAppID
        case invalidResponse
        case appNotFound
    }

    // MARK: Raw response shape

    private struct Envelope: Decodable {
        let success: Bool
        let data: RawDetails?
    }

    private struct RawDetails: Decodable {
        let name: String?
        let developers: [String]?
        let publishers: [String]?
        let shortDescription: String?
        let genres: [RawGenre]?
        let categories: [RawCategory]?
        let releaseDate: RawReleaseDate?

        enum CodingKeys: String, CodingKey {
            case name
            case developers
            case publishers
            case shortDescription = "short_description"
            case genres
            case categories
            case releaseDate = "release_date"
        }
    }

    private struct RawGenre: Decodable {
        let description: String
    }

    private struct RawCategory: Decodable {
        let description: String
    }

    private struct RawReleaseDate: Decodable {
        let comingSoon: Bool
        let date: String

        enum CodingKeys: String, CodingKey {
            case comingSoon = "coming_soon"
            case date
        }
    }

    // MARK: Fetch

    static func fetchDetails(forSteamAppID appID: String) async throws -> Details {

        guard
            !appID.trimmingCharacters(in: .whitespaces).isEmpty,
            let url = URL(
                string:
                    "https://store.steampowered.com/api/appdetails?appids=\(appID)&cc=us&l=en"
            )
        else {
            throw ServiceError.invalidAppID
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let response = response as? HTTPURLResponse,
              200..<300 ~= response.statusCode else {
            throw ServiceError.invalidResponse
        }

        // The response is keyed by the app id itself, e.g. { "440": { "success": true, "data": {...} } }
        let envelopes = try JSONDecoder().decode(
            [String: Envelope].self,
            from: data
        )

        guard
            let envelope = envelopes[appID],
            envelope.success,
            let raw = envelope.data
        else {
            throw ServiceError.appNotFound
        }

        return Details(
            name: raw.name ?? "",
            developers: raw.developers ?? [],
            publishers: raw.publishers ?? [],
            shortDescription: raw.shortDescription ?? "",
            genres: raw.genres?.map(\.description) ?? [],
            categories: raw.categories?.map(\.description) ?? [],
            releaseDate: parseReleaseDate(raw.releaseDate?.date)
        )
    }

    /// Steam's release date strings look like "21 Aug, 2012" or "Coming soon".
    /// Best-effort parse; returns nil if the format doesn't match.
    private static func parseReleaseDate(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM, yyyy"

        return formatter.date(from: string)
    }
}

// MARK: - Game Editor View

struct GameEditorView: View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject
    private var store = GameStore.shared

    let originalGame: Game

    // MARK: - Metadata fields

    @State private var name: String
    @State private var developers: String
    @State private var publisher: String
    @State private var description: String
    @State private var genres: String
    @State private var platforms: String
    @State private var categoriesText: String
    @State private var releaseDate: Date
    @State private var steamAppID: String
    @State private var fetchFromSteam: Bool

    // MARK: - Other state

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingFilePicker = false
    @State private var isFetchingSteamMetadata = false
    @State private var steamFetchErrorMessage: String?

    init(game: Game) {
        self.originalGame = game

        _name =
            State(
                initialValue: game.name
            )
        _developers =
            State(
                initialValue: game.developers
            )
        _publisher =
            State(
                initialValue: game.publisher
            )
        _description =
            State(
                initialValue: game.description
            )
        _genres =
            State(
                initialValue: game.genres
            )
        _platforms =
            State(
                initialValue: game.platforms
            )
        _categoriesText =
            State(
                initialValue:
                    game.categories.joined(separator: ", ")
            )
        _releaseDate =
            State(
                initialValue: game.releaseDate
            )
        _steamAppID =
            State(
                initialValue: game.steamAppID
            )
        _fetchFromSteam =
            State(
                initialValue: game.fetchFromSteam
            )
    }

    var body: some View {
        NavigationStack {
            Form {

                Section {
                    Toggle(
                        "Fetch Metadata From Steam",
                        isOn: $fetchFromSteam
                    )
                }

                if fetchFromSteam {

                    Section {
                        TextField(
                            "Steam App ID",
                            text: $steamAppID,
                            axis: .vertical
                        )
                    } header: {
                        Text("Steam")
                    } footer: {
                        Text(
                            "Metadata will be fetched automatically using this Steam App ID."
                        )
                    }

                    if let steamFetchErrorMessage {
                        Section {
                            Text(steamFetchErrorMessage)
                                .foregroundStyle(.red)
                        }
                    }

                } else {

                    Section("Name") {
                        TextField(
                            "Name",
                            text: $name
                        )
                    }

                    Section("Description") {
                        TextField(
                            "Description",
                            text: $description,
                            axis: .vertical
                        )
                    }

                    Section("Credits") {
                        TextField(
                            "Developers",
                            text: $developers
                        )
                        TextField(
                            "Publisher",
                            text: $publisher
                        )
                    }

                    Section {
                        TextField(
                            "Genres",
                            text: $genres
                        )
                        TextField(
                            "Platforms",
                            text: $platforms
                        )
                        TextField(
                            "Categories",
                            text: $categoriesText,
                            axis: .vertical
                        )
                        DatePicker(
                            "Release Date",
                            selection: $releaseDate,
                            displayedComponents: .date
                        )
                    } header: {
                        Text("Classification")
                    } footer: {
                        Text(
                            "Separate multiple categories with commas."
                        )
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
                    if isFetchingSteamMetadata {
                        ProgressView()
                    } else {
                        Button("Save") {
                            save()
                        }
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
            .disabled(isFetchingSteamMetadata)
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

    // MARK: - Save

    private func save() {
        var game = originalGame

        game.name =
            name.isEmpty
                ? "Imported Game"
                : name

        game.fetchFromSteam = fetchFromSteam
        game.steamAppID = steamAppID

        if fetchFromSteam {
            steamFetchErrorMessage = nil
            isFetchingSteamMetadata = true

            Task {
                await fetchSteamMetadataAndSave(baseGame: game)
            }
        } else {
            game.developers = developers
            game.publisher = publisher
            game.description = description
            game.genres = genres
            game.platforms = platforms
            game.releaseDate = releaseDate
            game.categories =
                categoriesText
                    .split(separator: ",")
                    .map {
                        $0.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                    }
                    .filter { !$0.isEmpty }

            store.update(game)
            dismiss()
        }
    }

    /// Runs once editing finishes when "Fetch Metadata From Steam" is on:
    /// looks up the Steam App ID, fills in the metadata fields from the
    /// response, then saves. Falls back to saving whatever was already
    /// entered if the fetch fails.
    private func fetchSteamMetadataAndSave(baseGame: Game) async {
        var game = baseGame

        do {
            let details = try await SteamAppDetailsService.fetchDetails(
                forSteamAppID: game.steamAppID
            )

            if !details.name.isEmpty {
                game.name = details.name
            }
            game.developers = details.developers.joined(separator: ", ")
            game.publisher = details.publishers.joined(separator: ", ")
            game.description = details.shortDescription
            game.genres = details.genres.joined(separator: ", ")
            game.categories = details.categories
            if let releaseDate = details.releaseDate {
                game.releaseDate = releaseDate
            }

        } catch {
            steamFetchErrorMessage =
                "Couldn't fetch metadata from Steam. Saved with the Steam App ID only."
        }

        isFetchingSteamMetadata = false
        store.update(game)
        dismiss()
    }
}
