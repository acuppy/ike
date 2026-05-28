import Foundation
import Observation

// Local-first sync: BlockLogger keeps writing the JSONL (source of truth);
// BlockSyncer scans for entries we haven't pushed yet and POSTs them to the
// server, retrying on failure. The set of synced external_ids lives in
// UserDefaults so the JSONL file format stays untouched. Each entry's
// external_id is its start timestamp in ISO8601 — stable, unique per user,
// and the server upsert is keyed on it, so retries are safe.
@MainActor
@Observable
final class BlockSyncer {
    private let settings: ServerSettings
    private let logger: BlockLogger
    private let defaults = UserDefaults.standard
    private let syncedKey = "SyncedExternalIds"

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    var isSyncing: Bool = false
    var lastError: String?

    init(settings: ServerSettings, logger: BlockLogger = .shared) {
        self.settings = settings
        self.logger = logger
        NotificationCenter.default.addObserver(
            forName: .blockLoggerDidChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let entry = note.userInfo?["entry"] as? BlockEntry else { return }
            Task { @MainActor in self?.resync(entry) }
        }
    }

    // Kick a sync run. Safe to call repeatedly; no-ops if nothing to push or
    // if we're already mid-flight.
    func sync() {
        guard settings.isConnected, let token = settings.apiToken else { return }
        guard !isSyncing else { return }

        let entries = logger.allEntries()
        var synced = syncedIds()
        let pending = entries.filter { !synced.contains(externalId(for: $0)) }
        guard !pending.isEmpty else {
            settings.lastSyncedAt = Date()
            return
        }

        isSyncing = true
        Task { [weak self] in
            await self?.push(pending, token: token, alreadySynced: &synced)
        }
    }

    // Mark an entry as needing a push (e.g. after an in-place edit) and run.
    func resync(_ entry: BlockEntry) {
        var synced = syncedIds()
        synced.remove(externalId(for: entry))
        saveSyncedIds(synced)
        sync()
    }

    func externalId(for entry: BlockEntry) -> String {
        isoFormatter.string(from: entry.start)
    }

    // The local JSONL uses the Swift enum case name "breakTime"; the server's
    // canonical wire format (and the future iOS app's) uses "break". Translate
    // here so the JSONL stays backward-compatible.
    private static func wireQuadrant(_ q: Quadrant) -> String {
        q == .breakTime ? "break" : q.rawValue
    }

    // MARK: - Push

    private func push(_ entries: [BlockEntry], token: String, alreadySynced synced: inout Set<String>) async {
        defer { Task { @MainActor in self.isSyncing = false } }

        guard let url = blocksEndpoint() else {
            await setError("Invalid server URL")
            return
        }

        for entry in entries {
            let id = externalId(for: entry)
            do {
                try await postBlock(entry, externalId: id, to: url, token: token)
                synced.insert(id)
            } catch {
                await setError("Sync failed: \(error.localizedDescription)")
                // Persist whatever we managed to push and bail; the next
                // sync run will pick up where we left off.
                saveSyncedIds(synced)
                return
            }
        }

        saveSyncedIds(synced)
        await markSuccess()
    }

    private func postBlock(_ entry: BlockEntry, externalId: String, to url: URL, token: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "block": [
                "external_id": externalId,
                "starts_at": isoFormatter.string(from: entry.start),
                "ends_at": isoFormatter.string(from: entry.end),
                "quadrant": Self.wireQuadrant(entry.quadrant),
                "note": entry.note,
                "auto": entry.auto
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "BlockSyncer", code: status, userInfo: [NSLocalizedDescriptionKey: "HTTP \(status)"])
        }
    }

    private func blocksEndpoint() -> URL? {
        guard var components = URLComponents(string: settings.serverURL) else { return nil }
        components.path = "/api/v1/blocks"
        return components.url
    }

    // MARK: - Persistence of synced ids

    private func syncedIds() -> Set<String> {
        Set(defaults.array(forKey: syncedKey) as? [String] ?? [])
    }

    private func saveSyncedIds(_ ids: Set<String>) {
        defaults.set(Array(ids), forKey: syncedKey)
    }

    // Reset everything (used on disconnect — next connect starts fresh).
    func forgetSyncedIds() {
        defaults.removeObject(forKey: syncedKey)
    }

    private func markSuccess() async {
        await MainActor.run {
            self.lastError = nil
            self.settings.lastSyncedAt = Date()
        }
    }

    private func setError(_ message: String) async {
        await MainActor.run { self.lastError = message }
    }
}
