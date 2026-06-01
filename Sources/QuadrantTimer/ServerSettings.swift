import Foundation
import Observation

// All the state the macOS widget needs to talk to the Ike backend:
// server URL + connected email (UserDefaults), API token (Keychain).
//
// All four are exposed as stored, tracked properties on this @Observable
// class so SwiftUI views reliably re-render when any of them change. The
// Keychain is still the authoritative store for the token (it survives if
// this in-memory cache is rebuilt at app launch), but we mirror the value
// in the `apiToken` property so observation propagates cleanly without
// going through a computed Keychain read.
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

    // In-memory cache of the Keychain token. Tracked by @Observable so
    // setting it triggers SwiftUI invalidation; the Keychain remains the
    // persistent store and is loaded at init() / written on connect().
    private(set) var apiToken: String?

    init() {
        self.serverURL = defaults.string(forKey: Keys.serverURL) ?? Self.defaultServerURL
        self.connectedEmail = defaults.string(forKey: Keys.connectedEmail)
        self.lastSyncedAt = defaults.object(forKey: Keys.lastSyncedAt) as? Date
        self.apiToken = KeychainStore.read(Keys.apiTokenAccount)
    }

    var isConnected: Bool {
        apiToken != nil && connectedEmail != nil
    }

    // Called by the URL handler after the server redirects to ike://connected.
    func connect(token: String, email: String) {
        KeychainStore.write(token, account: Keys.apiTokenAccount)
        apiToken = token
        connectedEmail = email
    }

    func disconnect() {
        KeychainStore.delete(Keys.apiTokenAccount)
        apiToken = nil
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
