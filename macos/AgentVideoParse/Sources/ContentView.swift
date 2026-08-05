import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class ExportModel: ObservableObject {
    @Published var status: String = "Ready. Choose a short video (≤30s)."
    @Published var lastOutput: String?
    @Published var lastLogPath: String?
    @Published var busy = false
    @Published var debugEnabled = false
    @Published var outputRoot: String = VideoExporter.defaultOutputRoot().path
    @Published var isDropTargeted = false

    func toggleDebug(_ on: Bool) {
        debugEnabled = on
        if on {
            lastLogPath = DebugLog.shared.setEnabled(true)
            DebugLog.shared.log("GUI: debug logging enabled")
            status = "Debug logging ON\n\(lastLogPath ?? "")"
        } else {
            DebugLog.shared.log("GUI: debug logging disabled")
            _ = DebugLog.shared.setEnabled(false)
            status = "Debug logging OFF"
        }
    }

    func openLog() {
        guard let path = lastLogPath ?? DebugLog.shared.logPath,
              FileManager.default.fileExists(atPath: path) else {
            status = "No debug log yet. Enable Debug logging first."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func copyLogPath() {
        guard let path = lastLogPath ?? DebugLog.shared.logPath else {
            status = "No debug log path yet."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        status = "Copied log path:\n\(path)"
    }

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .avi, .mpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a debug video (30 seconds or shorter)"
        if panel.runModal() == .OK, let url = panel.url {
            runExport(url: url)
        }
    }

    func chooseOutputRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            outputRoot = url.path
            DebugLog.shared.log("output root \(url.path)")
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

    func runExport(url: URL) {
        busy = true
        status = "Processing: \(url.lastPathComponent)…"
        lastOutput = nil
        DebugLog.shared.log("GUI start_export \(url.path)")

        let rootPath = outputRoot
        Task.detached(priority: .userInitiated) {
            do {
                let root = URL(fileURLWithPath: rootPath, isDirectory: true)
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                let out = try VideoExporter.makeRunDirectory(root: root, source: url)
                let result = try VideoExporter.export(
                    input: url,
                    outputDirectory: out,
                    progress: { i, n in
                        Task { @MainActor in
                            self.status = "Exporting frame \(i)/\(n)…"
                        }
                    }
                )
                await MainActor.run {
                    self.busy = false
                    self.lastOutput = result.outputDirectory.path
                    let bytes = (try? Self.folderByteSize(result.outputDirectory)) ?? 0
                    let mb = Double(bytes) / 1_048_576.0
                    var msg = "Wrote \(result.frameCount) agent-friendly JPEGs (\(String(format: "%.2f", result.durationSeconds))s, \(String(format: "%.1f", mb)) MB)\n\(result.outputDirectory.path)"
                    if DebugLog.shared.isEnabled, let log = DebugLog.shared.logPath {
                        self.lastLogPath = log
                        msg += "\nDebug log: \(log)"
                    }
                    self.status = msg
                }
            } catch {
                await MainActor.run {
                    self.busy = false
                    var msg = error.localizedDescription
                    if DebugLog.shared.isEnabled, let log = DebugLog.shared.logPath {
                        self.lastLogPath = log
                        msg += "\n\nDebug log: \(log)"
                    }
                    self.status = msg
                    let alert = NSAlert()
                    alert.messageText = "AgentVideoParse"
                    alert.informativeText = msg
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var model = ExportModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
                   let icon = NSImage(contentsOf: iconURL) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("AgentVideoParse")
                        .font(.title.bold())
                    Text("Short debug video → ordered screenshots for AI agents")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }

            GroupBox("Disclaimer (always visible)") {
                Text(AVPConstants.disclaimer)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
            }
            .background(Color.yellow.opacity(0.2))

            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [8]),
                    antialiased: true
                )
                .foregroundStyle(model.isDropTargeted ? Color.accentColor : Color.secondary)
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
                .onDrop(of: [.fileURL], isTargeted: $model.isDropTargeted) { providers in
                    guard !model.busy else { return false }
                    guard let provider = providers.first else { return false }
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url {
                            DispatchQueue.main.async { model.runExport(url: url) }
                        }
                    }
                    return true
                }

            HStack {
                Text("Output folder:")
                TextField("Output root", text: $model.outputRoot)
                Button("Change") { model.chooseOutputRoot() }
            }

            Text("Sampling: \(AVPConstants.defaultSampleFPS) fps · max \(AVPConstants.maxFrames) stills · ≤\(Int(AVPConstants.durationLimitSeconds))s · JPEG ≤\(AVPConstants.maxLongEdge)px")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Toggle("Debug logging", isOn: Binding(
                    get: { model.debugEnabled },
                    set: { model.toggleDebug($0) }
                ))
                Button("Open debug log") { model.openLog() }
                    .disabled(model.lastLogPath == nil && DebugLog.shared.logPath == nil)
                Button("Copy log path") { model.copyLogPath() }
                    .disabled(model.lastLogPath == nil && DebugLog.shared.logPath == nil)
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

            Spacer(minLength: 0)
            Text("Open Source · Debug only · ≤30s · macOS app")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 600)
    }
}

extension ExportModel {
    nonisolated static func folderByteSize(_ dir: URL) throws -> Int64 {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for f in files {
            if let n = try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(n)
            }
        }
        return total
    }
}
