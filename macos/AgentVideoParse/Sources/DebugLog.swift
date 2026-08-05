import Foundation

final class DebugLog: @unchecked Sendable {
    static let shared = DebugLog()

    private let lock = NSLock()
    private(set) var isEnabled = false
    private(set) var logPath: String?

    private init() {}

    @discardableResult
    func setEnabled(_ enabled: Bool) -> String? {
        lock.lock()
        defer { lock.unlock() }
        isEnabled = enabled
        if !enabled {
            if let path = logPath {
                appendUnlocked("=== debug logging DISABLED at \(isoNow()) ===", path: path)
            }
            return logPath
        }
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/AgentVideoParse/logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let file = dir.appendingPathComponent("agentvideoparse-debug-\(stamp).log")
        let header = """
        === AgentVideoParse macOS app debug log started \(isoNow()) ===
        Local only; not uploaded.

        """
        try? header.write(to: file, atomically: true, encoding: .utf8)
        logPath = file.path
        return logPath
    }

    func log(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        guard isEnabled, let path = logPath else { return }
        appendUnlocked("[\(isoNow())] \(message)", path: path)
    }

    private func appendUnlocked(_ line: String, path: String) {
        let url = URL(fileURLWithPath: path)
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        if let data = (line + "\n").data(using: .utf8) {
            handle.write(data)
        }
    }

    private func isoNow() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
