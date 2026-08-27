import Foundation
import SwiftUI

// MARK: - Image Cache

final class ImageCache {

    static let shared = ImageCache()

    private let cache = NSCache<NSURL, NSData>()

    private init() {
        cache.countLimit = 100
    }

    func data(for url: URL) -> Data? {
        cache.object(forKey: url as NSURL) as Data?
    }

    func insert(_ data: Data, for url: URL) {
        cache.setObject(data as NSData, forKey: url as NSURL)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}

// MARK: - Image Loader

final class ImageLoader {

    static let shared = ImageLoader()

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: configuration)
    }

    func data(from url: URL) async throws -> Data {

        // First check our in-memory cache.
        if let cached = ImageCache.shared.data(for: url) {
            return cached
        }

        // Otherwise download/load from URLSession.
        let (data, response) = try await session.data(from: url)

        guard let response = response as? HTTPURLResponse,
              200..<300 ~= response.statusCode else {
            throw URLError(.badServerResponse)
        }

        // Store the downloaded image data.
        ImageCache.shared.insert(data, for: url)
        return data
    }
}

// MARK: - Cached Async Image

struct CachedAsyncImage<Content: View>: View {

    let url: URL?
    let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    init(
        url: URL?,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                await load()
            }
    }

    private func load() async {
        guard let url else {
            phase = .empty
            return
        }

        phase = .empty

        do {
            let data = try await ImageLoader.shared.data(from: url)
            guard let image = makeImage(from: data) else {
                throw URLError(.cannotDecodeContentData)
            }
            phase = .success(image)
        } catch {
            phase = .failure(error)
        }
    }

    private func makeImage(from data: Data) -> Image? {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: data) else {
            return nil
        }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }
}

// MARK: - Game Art Cache

/// Simple, thread-safe cache mapping a game's name straight to its
/// resolved art URLs. One entry per game name, shared app-wide via
/// `.shared`, so it survives no matter how many `GameArtProvider` /
/// `SteamGridDB` instances get created (e.g. one per `GameCard`).
actor GameArtCache {

    static let shared = GameArtCache()

    private init() {}

    struct Art {
        var heroURL: URL?
        var gridURL: URL?
        var logoURL: URL?
    }

    /// game name -> resolved art
    private var artByGameName: [String: Art] = [:]

    func art(forGameName name: String) -> Art? {
        artByGameName[name]
    }

    func setHeroURL(_ url: URL?, forGameName name: String) {
        var art = artByGameName[name] ?? Art()
        art.heroURL = url
        artByGameName[name] = art
    }

    func setGridURL(_ url: URL?, forGameName name: String) {
        var art = artByGameName[name] ?? Art()
        art.gridURL = url
        artByGameName[name] = art
    }

    func setLogoURL(_ url: URL?, forGameName name: String) {
        var art = artByGameName[name] ?? Art()
        art.logoURL = url
        artByGameName[name] = art
    }
}

// MARK: - SteamGridDB

/// Thin client for the SteamGridDB API (https://www.steamgriddb.com/api/v2).
/// Used to look up box art / heroes / logos for games that are *not*
/// linked to a Steam App ID, by searching on the game's name.
final class SteamGridDB {

    // MARK: Response models

    private struct SearchResponse: Decodable {
        let success: Bool
        let data: [SearchResult]
    }

    private struct SearchResult: Decodable {
        let id: Int
        let name: String
    }

    private struct ArtResponse: Decodable {
        let success: Bool
        let data: [ArtResult]
    }

    private struct ArtResult: Decodable {
        let id: Int
        let url: String
    }

    private enum ArtKind: String {
        case hero = "heroes"
        case grid = "grids"
        case logo = "logos"
    }

    // MARK: Init

    private let apiKey: String
    private let session: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey
        self.session = URLSession(configuration: .default)
    }

    // MARK: Search

    /// Resolves a SteamGridDB game id from a free-text game name.
    /// Not cached here — `GameArtProvider` caches the *final* art URL
    /// per game name, which is the thing views actually ask for.
    func gameID(forName name: String) async throws -> Int? {

        guard
            let encodedName = name.addingPercentEncoding(
                withAllowedCharacters: .urlPathAllowed
            ),
            let url = URL(
                string:
                    "https://www.steamgriddb.com/api/v2/search/autocomplete/\(encodedName)"
            )
        else {
            return nil
        }

        let response: SearchResponse = try await get(url)
        return response.data.first?.id
    }

    // MARK: Art lookups (by SteamGridDB game id)

    func heroURL(forGameID gameID: Int) async throws -> URL? {
        try await artURL(kind: .hero, gameID: gameID)
    }

    func gridURL(forGameID gameID: Int) async throws -> URL? {
        try await artURL(kind: .grid, gameID: gameID)
    }

    func logoURL(forGameID gameID: Int) async throws -> URL? {
        try await artURL(kind: .logo, gameID: gameID)
    }

    private func artURL(kind: ArtKind, gameID: Int) async throws -> URL? {

        guard
            let url = URL(
                string:
                    "https://www.steamgriddb.com/api/v2/\(kind.rawValue)/game/\(gameID)"
            )
        else {
            return nil
        }

        let response: ArtResponse = try await get(url)

        guard let first = response.data.first else {
            return nil
        }

        return URL(string: first.url)
    }

    // MARK: Networking

    private func get<T: Decodable>(_ url: URL) async throws -> T {

        var request = URLRequest(url: url)
        request.setValue(
            "Bearer \(apiKey)",
            forHTTPHeaderField: "Authorization"
        )

        let (data, response) = try await session.data(for: request)

        guard let response = response as? HTTPURLResponse,
              200..<300 ~= response.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Game Art Provider

/// Resolves art (hero / grid / logo) for a `Game`.
///
/// - If `game.fetchFromSteam` is `true`, art comes directly from Steam's
///   CDN using `game.steamAppID`.
/// - Otherwise, art is resolved via the SteamGridDB API by searching on
///   `game.name`.
///
/// The resolved URL for each game name is cached in `GameArtCache.shared`,
/// so once a game's art has been looked up once, every subsequent call —
/// from any `GameArtProvider` instance, anywhere in the app — returns
/// instantly without hitting the network again.
final class GameArtProvider {

    private let steamGridDB: SteamGridDB
    private let cache = GameArtCache.shared

    init(steamGridDBAPIKey: String) {
        self.steamGridDB = SteamGridDB(apiKey: steamGridDBAPIKey)
    }

    func heroURL(for game: Game) async throws -> URL? {

        if let cached = await cache.art(forGameName: game.name)?.heroURL {
            return cached
        }

        let url: URL?
        if game.fetchFromSteam {
            url = steamCDNHeroURL(forSteamAppID: game.steamAppID)
        } else if let id = try await gridDBGameID(for: game) {
            url = try await steamGridDB.heroURL(forGameID: id)
        } else {
            url = nil
        }

        await cache.setHeroURL(url, forGameName: game.name)
        return url
    }

    func gridURL(for game: Game) async throws -> URL? {

        if let cached = await cache.art(forGameName: game.name)?.gridURL {
            return cached
        }

        let url: URL?
        if game.fetchFromSteam {
            url = steamCDNGridURL(forSteamAppID: game.steamAppID)
        } else if let id = try await gridDBGameID(for: game) {
            url = try await steamGridDB.gridURL(forGameID: id)
        } else {
            url = nil
        }

        await cache.setGridURL(url, forGameName: game.name)
        return url
    }

    func logoURL(for game: Game) async throws -> URL? {

        if let cached = await cache.art(forGameName: game.name)?.logoURL {
            return cached
        }

        let url: URL?
        if game.fetchFromSteam {
            url = steamCDNLogoURL(forSteamAppID: game.steamAppID)
        } else if let id = try await gridDBGameID(for: game) {
            url = try await steamGridDB.logoURL(forGameID: id)
        } else {
            url = nil
        }

        await cache.setLogoURL(url, forGameName: game.name)
        return url
    }

    // MARK: SteamGridDB lookup helper

    private func gridDBGameID(for game: Game) async throws -> Int? {
        try await steamGridDB.gameID(forName: game.name)
    }

    // MARK: Steam CDN (direct, when fetchFromSteam is true)

    private func steamCDNHeroURL(forSteamAppID appID: String) -> URL? {
        URL(
            string:
                "https://steamcdn-a.akamaihd.net/steam/apps/\(appID)/library_hero.jpg"
        )
    }

    private func steamCDNGridURL(forSteamAppID appID: String) -> URL? {
        URL(
            string:
                "https://steamcdn-a.akamaihd.net/steam/apps/\(appID)/library_600x900_2x.jpg"
        )
    }

    private func steamCDNLogoURL(forSteamAppID appID: String) -> URL? {
        URL(
            string:
                "https://steamcdn-a.akamaihd.net/steam/apps/\(appID)/logo.png"
        )
    }
}
