import SwiftUI
import AppKit

@main
struct AgentVideoParseApp: App {
    init() {
        // CLI: AgentVideoParse.app/Contents/MacOS/AgentVideoParse export <video> [-o dir]
        let args = CommandLine.arguments
        if args.count >= 2, args[1] == "export" {
            CLIExport.run(Array(args.dropFirst()))
            NSApp.terminate(nil)
        }
        if args.count >= 2, args[1] == "help" || args[1] == "--help" || args[1] == "-h" {
            fputs(
                """
                AgentVideoParse (macOS app)
                  (no args)              Open GUI
                  export <video> [-o dir]  Export frames (CLI)
                  help

                """,
                stderr
            )
            exit(0)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 560, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

enum CLIExport {
    static func run(_ args: [String]) {
        // args[0] == "export"
        guard args.count >= 2 else {
            fputs("usage: export <video> [-o dir]\n", stderr)
            exit(1)
        }
        var video: String?
        var out: String?
        var i = 1
        while i < args.count {
            if args[i] == "-o", i + 1 < args.count {
                out = args[i + 1]
                i += 2
                continue
            }
            if video == nil {
                video = args[i]
            }
            i += 1
        }
        guard let video else {
            fputs("usage: export <video> [-o dir]\n", stderr)
            exit(1)
        }
        do {
            let input = URL(fileURLWithPath: video)
            let outputURL = out.map { URL(fileURLWithPath: $0, isDirectory: true) }
            let result = try VideoExporter.export(input: input, outputDirectory: outputURL)
            print(result.outputDirectory.path)
            print("frames=\(result.frameCount) duration=\(String(format: "%.3f", result.durationSeconds))s")
            exit(0)
        } catch let e as ExportError {
            fputs("ERROR: \(e.localizedDescription)\n", stderr)
            switch e {
            case .tooLong:
                exit(2)
            default:
                exit(1)
            }
        } catch {
            fputs("ERROR: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
