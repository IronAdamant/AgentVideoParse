import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// macOS GUI shell — SwiftUI, system frameworks only.
/// Invokes the shared Python export path so DurationGate is the shipped core.
/// Includes Debug logging toggle + open/copy log path.

@main
struct AgentVideoParseApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

enum AVPConstants {
    static let disclaimer = """
    DISCLAIMER

    • Your video file must be 60 seconds or shorter. Longer files are rejected; no frames are extracted.
    • AgentVideoParse is a debugging tool for AI/agent UI review only. Do not use it as a general video editor or archival converter.
    • This software is fully open source and runs locally on your computer (macOS, Windows, or Linux). It does not upload your video.
    """
    static let limitSeconds = 30.0
    static let sampleFps = 2.0
    static let maxFrames = 60
}

final class ExportModel: ObservableObject {
    @Published var status: String = "Ready."
    @Published var lastOutput: String?
    @Published var lastLogPath: String?
    @Published var busy = false
    @Published var debugEnabled = false
    @Published var outputRoot: String = NSString(string: "~/Movies/AgentVideoParse").expandingTildeInPath

    private var logFileHandle: FileHandle?

    func toggleDebug(_ on: Bool) {
        debugEnabled = on
        if on {
            let dir = (NSString(string: "~/Movies/AgentVideoParse/logs").expandingTildeInPath as NSString)
            try? FileManager.default.createDirectory(atPath: dir as String, withIntermediateDirectories: true)
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let path = (dir as String) + "/agentvideoparse-debug-\(stamp).log"
            FileManager.default.createFile(atPath: path, contents: nil)
            lastLogPath = path
            uiLog("Debug logging enabled path=\(path)")
            status = "Debug logging ON\n\(path)"
        } else {
            uiLog("Debug logging disabled")
            status = "Debug logging OFF"
        }
    }

    func uiLog(_ message: String) {
        guard debugEnabled, let path = lastLogPath else { return }
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        if let data = line.data(using: .utf8) {
            if let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                defer { try? h.close() }
                h.seekToEndOfFile()
                h.write(data)
            }
        }
    }

    func openLog() {
        guard let path = lastLogPath, FileManager.default.fileExists(atPath: path) else {
            status = "No debug log yet. Enable Debug logging first."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func copyLogPath() {
        guard let path = lastLogPath else {
            status = "No debug log path yet."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        status = "Copied log path:\n\(path)"
    }

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .avi]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            runExport(path: url.path)
        }
    }

    func chooseOutputRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            outputRoot = url.path
            uiLog("output root changed to \(url.path)")
        }
    }

    func reveal() {
        guard let lastOutput else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: lastOutput))
    }

    func copyPath() {
        guard let lastOutput else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastOutput, forType: .string)
        status = "Copied path:\n\(lastOutput)"
    }

    func runExport(path: String) {
        busy = true
        status = "Processing: \(URL(fileURLWithPath: path).lastPathComponent)…"
        lastOutput = nil
        let root = outputRoot
        let debug = debugEnabled
        let logPath = lastLogPath
        uiLog("runExport path=\(path)")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.invokePythonExport(
                video: path,
                outputRoot: root,
                debug: debug,
                debugLogPath: logPath
            )
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success(let out):
                    self.lastOutput = out
                    var msg = "Wrote screenshots to:\n\(out)"
                    if debug, let logPath { msg += "\nDebug log: \(logPath)" }
                    self.status = msg
                    self.uiLog("export success \(out)")
                case .failure(let msg):
                    var m = msg
                    if debug, let logPath { m += "\nDebug log: \(logPath)" }
                    self.status = m
                    self.uiLog("export failure \(msg)")
                }
            }
        }
    }

    private static func invokePythonExport(
        video: String,
        outputRoot: String,
        debug: Bool,
        debugLogPath: String?
    ) -> Result<String, String> {
        let repo = findRepoRoot()
        let py = Process()
        py.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
        let outDir = (outputRoot as NSString).appendingPathComponent("export-\(stamp)")
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        py.arguments = [
            "python3", "-m", "avp", "export", video, "-o", outDir
        ]
        var env = ProcessInfo.processInfo.environment
        let core = (repo as NSString).appendingPathComponent("shared/core")
        env["PYTHONPATH"] = "\(core):\(repo)"
        if debug {
            env["AVP_DEBUG"] = "1"
            if let debugLogPath {
                env["AVP_DEBUG_LOG"] = debugLogPath
            }
        }
        py.environment = env
        py.currentDirectoryURL = URL(fileURLWithPath: repo)
        let outPipe = Pipe()
        let errPipe = Pipe()
        py.standardOutput = outPipe
        py.standardError = errPipe
        do {
            try py.run()
            py.waitUntilExit()
        } catch {
            return .failure("Failed to start export: \(error.localizedDescription)")
        }
        let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if py.terminationStatus == 0 {
            let dir = stdout.split(separator: "\n").first.map(String.init) ?? outDir
            return .success(dir)
        }
        return .failure(stderr.isEmpty ? stdout : stderr)
    }

    private static func findRepoRoot() -> String {
        if let exec = Bundle.main.executableURL {
            var url = exec.deletingLastPathComponent()
            for _ in 0..<6 {
                let marker = url.appendingPathComponent("shared/core/avp")
                if FileManager.default.fileExists(atPath: marker.path) {
                    return url.path
                }
                url.deleteLastPathComponent()
            }
        }
        let cwd = FileManager.default.currentDirectoryPath
        if FileManager.default.fileExists(atPath: (cwd as NSString).appendingPathComponent("shared/core/avp")) {
            return cwd
        }
        return cwd
    }
}

struct ContentView: View {
    @StateObject private var model = ExportModel()
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AgentVideoParse")
                .font(.title.bold())
            Text("Short debug video → ordered screenshots for AI agents")
                .foregroundStyle(.secondary)

            GroupBox("Disclaimer (always visible)") {
                Text(AVPConstants.disclaimer)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
            }
            .background(Color.yellow.opacity(0.25))

            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.08))
                )
                .frame(minHeight: 140)
                .overlay(
                    Text(model.busy ? "Working…" : "Drop a video here (.mov, .mp4, …)\nor click to choose file")
                        .multilineTextAlignment(.center)
                )
                .onTapGesture { if !model.busy { model.chooseFile() } }
                .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
                    guard !model.busy else { return false }
                    guard let p = providers.first else { return false }
                    _ = p.loadObject(ofClass: URL.self) { url, _ in
                        if let url {
                            DispatchQueue.main.async { model.runExport(path: url.path) }
                        }
                    }
                    return true
                }

            HStack {
                Text("Output folder:")
                TextField("Output root", text: $model.outputRoot)
                Button("Change") { model.chooseOutputRoot() }
            }

            Text("Sampling: \(AVPConstants.sampleFps) fps · max \(AVPConstants.maxFrames) stills · max \(AVPConstants.limitSeconds)s duration")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Toggle("Debug logging", isOn: Binding(
                    get: { model.debugEnabled },
                    set: { model.toggleDebug($0) }
                ))
                Button("Open debug log") { model.openLog() }
                    .disabled(model.lastLogPath == nil)
                Button("Copy log path") { model.copyLogPath() }
                    .disabled(model.lastLogPath == nil)
            }

            Text(model.status)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

            HStack {
                Button("Reveal in Finder") { model.reveal() }
                    .disabled(model.lastOutput == nil)
                Button("Copy path") { model.copyPath() }
                    .disabled(model.lastOutput == nil)
            }

            Spacer()
            Text("Open Source · Debug only · ≤60s · macOS / Windows / Linux")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 600)
    }
}
