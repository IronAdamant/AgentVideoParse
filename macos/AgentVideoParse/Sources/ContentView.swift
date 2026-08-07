import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class ExportModel: ObservableObject {
    @Published var status: String = AVPConstants.readyStatus
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
    /// Product default is dark; user choice is persisted via AppStorage.
    @AppStorage(AVPConstants.appearanceStorageKey) private var appearance: String = AVPConstants.appearanceDark
    @Environment(\.colorScheme) private var colorScheme

    private var preferredScheme: ColorScheme? {
        appearance == AVPConstants.appearanceLight ? .light : .dark
    }

    private var isDark: Bool {
        (preferredScheme ?? colorScheme) == .dark
    }

    /// Amber disclaimer that stays readable in both themes (not pure system yellow wash).
    private var disclaimerBackground: Color {
        isDark
            ? Color(red: 0.42, green: 0.38, blue: 0.18).opacity(0.55)
            : Color(red: 1.0, green: 0.95, blue: 0.80)
    }

    private var disclaimerBorder: Color {
        isDark
            ? Color(red: 0.72, green: 0.64, blue: 0.28).opacity(0.45)
            : Color(red: 0.90, green: 0.80, blue: 0.40).opacity(0.7)
    }

    private var dropFill: Color {
        isDark ? Color.primary.opacity(0.06) : Color(red: 0.94, green: 0.96, blue: 0.97)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            disclaimerBox

            dropZone

            HStack {
                Text("Output folder:")
                TextField("Output root", text: $model.outputRoot)
                Button("Change") { model.chooseOutputRoot() }
            }

            Text(AVPConstants.samplingCaption)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(model.status)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)

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

            HStack {
                Button("Reveal in Finder") { model.reveal() }
                    .disabled(model.lastOutput == nil)
                Button("Copy path") { model.copyPath() }
                    .disabled(model.lastOutput == nil)
            }

            Spacer(minLength: 8)

            HStack(alignment: .center) {
                Text("Appearance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Appearance", selection: $appearance) {
                    Text("Dark").tag(AVPConstants.appearanceDark)
                    Text("Light").tag(AVPConstants.appearanceLight)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
                .labelsHidden()
                .accessibilityLabel("Appearance")

                Spacer()
            }

            Text(AVPConstants.footer)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 620)
        .preferredColorScheme(preferredScheme)
    }

    private var header: some View {
        HStack(spacing: 12) {
            // Flat transparent mark only — no clip, no plate (artwork has no baked squircle).
            if let mark = loadHeaderLogo() {
                Image(nsImage: mark)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 48)
                    .accessibilityLabel("AgentVideoParse")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("AgentVideoParse")
                    .font(.title.bold())
                Text("Short debug video → ordered screenshots for AI agents")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
    }

    /// Native-aspect LogoMark preferred; AppIcon is the same mark on a transparent square.
    private func loadHeaderLogo() -> NSImage? {
        for name in ["LogoMark", "AppIcon"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let img = NSImage(contentsOf: url) {
                return img
            }
        }
        return nil
    }

    private var disclaimerBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Disclaimer (always visible)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(AVPConstants.disclaimer)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(disclaimerBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(disclaimerBorder, lineWidth: 1)
        )
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                style: StrokeStyle(lineWidth: 2, dash: [8]),
                antialiased: true
            )
            .foregroundStyle(model.isDropTargeted ? Color.accentColor : Color.secondary)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(dropFill)
            )
            .frame(minHeight: 140)
            .overlay(
                Text(model.busy ? "Working…" : AVPConstants.dropZoneHint)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
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
