using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows;

namespace AgentVideoParse
{
    public partial class App : Application
    {
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool AttachConsole(int dwProcessId);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool AllocConsole();

        private const int AttachParentProcess = -1;

        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            // Headless CLI for tests / scripts (no installer; same exe as GUI):
            //   AgentVideoParse.exe export <video> [-o dir]
            //   AgentVideoParse.exe help
            var args = e.Args ?? new string[0];
            if (args.Length > 0)
            {
                EnsureConsole();
                int code = RunCli(args);
                Shutdown(code);
                return;
            }

            var window = new MainWindow();
            MainWindow = window;
            window.Show();
        }

        private static void EnsureConsole()
        {
            // Reuse the parent console when launched from cmd/PowerShell; else allocate one.
            if (!AttachConsole(AttachParentProcess))
                AllocConsole();
            // Refresh System.Console streams after attach
            try
            {
                var stdout = Console.OpenStandardOutput();
                var stderr = Console.OpenStandardError();
                var stdin = Console.OpenStandardInput();
                Console.SetOut(new StreamWriter(stdout) { AutoFlush = true });
                Console.SetError(new StreamWriter(stderr) { AutoFlush = true });
                Console.SetIn(new StreamReader(stdin));
            }
            catch
            {
                /* ignore */
            }
        }

        private static int RunCli(string[] args)
        {
            string cmd = args[0];
            if (string.Equals(cmd, "help", StringComparison.OrdinalIgnoreCase) ||
                cmd == "-h" || cmd == "--help" || cmd == "/?")
            {
                Console.WriteLine("AgentVideoParse (Windows native — one-click exe, no install)");
                Console.WriteLine("  (no args)              Open GUI");
                Console.WriteLine("  export <video> [-o d]  Export frames");
                Console.WriteLine("  help                   This message");
                return 0;
            }

            if (string.Equals(cmd, "export", StringComparison.OrdinalIgnoreCase))
            {
                if (args.Length < 2)
                {
                    Console.Error.WriteLine("ERROR: export requires a video path.");
                    return 1;
                }
                string video = args[1];
                string outDir = null;
                for (int i = 2; i < args.Length; i++)
                {
                    if ((args[i] == "-o" || args[i] == "--output") && i + 1 < args.Length)
                        outDir = args[++i];
                }
                try
                {
                    var result = VideoExporter.Export(video, outputDirectory: outDir);
                    Console.WriteLine(result.OutputDirectory);
                    Console.Error.WriteLine(
                        "OK frames=" + result.FrameCount +
                        " duration=" + result.DurationSeconds.ToString("F3") + "s");
                    return 0;
                }
                catch (ExportException ex)
                {
                    Console.Error.WriteLine(ex.Message);
                    return 2;
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine("ERROR: " + ex.Message);
                    return 1;
                }
            }

            Console.Error.WriteLine("Unknown command: " + cmd);
            return 1;
        }
    }
}
