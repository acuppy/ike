import Foundation

extension Notification.Name {
    // Posted on the main queue after BlockLogger writes (append or update),
    // with `entry` (BlockEntry) in userInfo. Lets observers (e.g. the
    // syncer) react without BlockLogger needing to know about them.
    static let blockLoggerDidChange = Notification.Name("BlockLoggerDidChange")
}

struct BlockEntry: Codable, Equatable {
    let start: Date
    let end: Date
    let quadrant: Quadrant
    let note: String
    let auto: Bool
}

final class BlockLogger: @unchecked Sendable {
    static let shared = BlockLogger()

    let fileURL: URL

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.withoutEscapingSlashes]
        return e
    }()

    private let queue = DispatchQueue(label: "QuadrantTimer.BlockLogger")

    init() {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("QuadrantTimer", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("log.jsonl")
    }

    func append(_ entry: BlockEntry) {
        queue.async { [fileURL, encoder] in
            do {
                var data = try encoder.encode(entry)
                data.append(0x0A)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    let handle = try FileHandle(forWritingTo: fileURL)
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.close()
                } else {
                    try data.write(to: fileURL, options: .atomic)
                }
                Self.notifyDidChange(entry)
            } catch {
                NSLog("BlockLogger append failed: \(error)")
            }
        }
    }

    func update(_ entry: BlockEntry, identifiedBy start: Date) {
        queue.async { [fileURL, encoder] in
            do {
                guard let data = try? Data(contentsOf: fileURL),
                      let text = String(data: data, encoding: .utf8) else { return }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                var output = Data()
                for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
                    if let lineData = line.data(using: .utf8),
                       let parsed = try? decoder.decode(BlockEntry.self, from: lineData),
                       parsed.start == start {
                        var newData = try encoder.encode(entry)
                        newData.append(0x0A)
                        output.append(newData)
                    } else if let lineData = line.data(using: .utf8) {
                        output.append(lineData)
                        output.append(0x0A)
                    }
                }
                try output.write(to: fileURL, options: .atomic)
                Self.notifyDidChange(entry)
            } catch {
                NSLog("BlockLogger update failed: \(error)")
            }
        }
    }

    private static func notifyDidChange(_ entry: BlockEntry) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .blockLoggerDidChange,
                object: nil,
                userInfo: ["entry": entry]
            )
        }
    }

    func todayEntries() -> [BlockEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8) else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: today) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var entries: [BlockEntry] = []
        for line in text.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let entry = try? decoder.decode(BlockEntry.self, from: lineData) else { continue }
            if entry.start >= today && entry.start < tomorrow {
                entries.append(entry)
            }
        }
        entries.sort { $0.start < $1.start }
        return entries
    }

    func allEntries() -> [BlockEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var entries: [BlockEntry] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let lineData = line.data(using: .utf8),
                  let entry = try? decoder.decode(BlockEntry.self, from: lineData) else { continue }
            entries.append(entry)
        }
        entries.sort { $0.start < $1.start }
        return entries
    }

    func weekEntries() -> [BlockEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8) else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let sevenDaysAgo = cal.date(byAdding: .day, value: -6, to: today),
              let tomorrow = cal.date(byAdding: .day, value: 1, to: today) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var entries: [BlockEntry] = []
        for line in text.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let entry = try? decoder.decode(BlockEntry.self, from: lineData) else { continue }
            if entry.start >= sevenDaysAgo && entry.start < tomorrow {
                entries.append(entry)
            }
        }
        entries.sort { $0.start < $1.start }
        return entries
    }
}
