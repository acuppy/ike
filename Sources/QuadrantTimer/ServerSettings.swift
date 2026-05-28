import Foundation
import Observation

// All the state the macOS widget needs to talk to the Ike backend:
// the server URL (UserDefaults, mutable from Preferences), the connected
// account's email for display (UserDefaults), and the API token (Keychain).
@MainActor
@Observable
final class ServerSettings {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let serverURL = "ServerURL"
        static let connectedEmail = "ServerConnectedEmail"
        static let apiTokenAccount = "ServerAPIToken"
        static let lastSyncedAt = "ServerLastSyncedAt"
    }

    static let defaultServerURL = "http://localhost:3000"

    var serverURL: String {
        didSet { defaults.set(serverURL, forKey: Keys.serverURL) }
    }

    var connectedEmail: String? {
        didSet { defaults.set(connectedEmail, forKey: Keys.connectedEmail) }
    }

    var lastSyncedAt: Date? {
        didSet { defaults.set(lastSyncedAt, forKey: Keys.lastSyncedAt) }
    }

    init() {
        self.serverURL = defaults.string(forKey: Keys.serverURL) ?? Self.defaultServerURL
        self.connectedEmail = defaults.string(forKey: Keys.connectedEmail)
        self.lastSyncedAt = defaults.object(forKey: Keys.lastSyncedAt) as? Date
    }

    var isConnected: Bool {
        apiToken != nil && connectedEmail != nil
    }

    var apiToken: String? {
        KeychainStore.read(Keys.apiTokenAccount)
    }

    // Called by the URL handler after the server redirects to ike://connected.
    func connect(token: String, email: String) {
        KeychainStore.write(token, account: Keys.apiTokenAccount)
        connectedEmail = email
    }

    func disconnect() {
        KeychainStore.delete(Keys.apiTokenAccount)
        connectedEmail = nil
        lastSyncedAt = nil
    }

    // URL the menu bar app opens in the user's browser to start the handoff.
    var connectURL: URL? {
        guard var components = URLComponents(string: serverURL) else { return nil }
        components.path = "/connect"
        components.queryItems = [URLQueryItem(name: "return_scheme", value: "ike")]
        return components.url
    }
}
