import Foundation

final class SteamGridDB {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func heroURL(forSteamAppID appID: Int?) async throws -> URL? {
        guard let appID else {
            return nil
        }
        let url = URL(
            string: "https://steamcdn-a.akamaihd.net/steam/apps/\(appID)/library_hero.jpg"
        )!
        
        return url
    }
    
    func gridURL(forSteamAppID appID: Int?) async throws -> URL? {
        guard let appID else {
            return nil
        }
        
        let url = URL(
            string: "https://steamcdn-a.akamaihd.net/steam/apps/\(appID)/library_600x900_2x.jpg"
        )!
        
        return url
    }
    
    func logoURL(forSteamAppID appID: Int?) async throws -> URL? {
        guard let appID else {
            return nil
        }
        
        let url = URL(
            string: "https://steamcdn-a.akamaihd.net/steam/apps/\(appID)/logo.png"
        )!
        
        return url
    }
}
