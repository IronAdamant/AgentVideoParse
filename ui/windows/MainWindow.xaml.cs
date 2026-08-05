using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Windows;
using System.Windows.Input;

namespace AgentVideoParse
{
    public partial class MainWindow : Window
    {
        private const string Disclaimer =
            "DISCLAIMER\n\n" +
            "• Your video file must be 30 seconds or shorter. Longer files are rejected; no frames are extracted.\n" +
            "• AgentVideoParse is a debugging tool for AI/agent UI review only. Do not use it as a general video editor or archival converter.\n" +
            "• This software is fully open source and runs locally on your computer (macOS, Windows, or Linux). It does not upload your video.\n";

        private string _lastOut;
        private string _lastLog;
        private bool _busy;

        public MainWindow()
        {
            InitializeComponent();
            DisclaimerText.Text = Disclaimer;
            var videos = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.MyVideos),
                "AgentVideoParse");
            OutputRootBox.Text = videos;
        }

        private string DefaultLogDir()
        {
            return Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.MyVideos),
                "AgentVideoParse", "logs");
        }

        private void UiLog(string message)
        {
            if (DebugCheck == null || DebugCheck.IsChecked != true) return;
            if (string.IsNullOrEmpty(_lastLog)) return;
            try
            {
                File.AppendAllText(_lastLog,
                    "[" + DateTime.UtcNow.ToString("o") + "] " + message + Environment.NewLine,
                    Encoding.UTF8);
            }
            catch { /* ignore log IO */ }
        }

        private void DebugCheck_Changed(object sender, RoutedEventArgs e)
        {
            if (DebugCheck.IsChecked == true)
            {
                var dir = DefaultLogDir();
                Directory.CreateDirectory(dir);
                _lastLog = Path.Combine(dir, "agentvideoparse-debug-" +
                    DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".log");
                File.WriteAllText(_lastLog,
                    "=== AgentVideoParse Windows GUI debug log " + DateTime.UtcNow.ToString("o") + " ===" +
                    Environment.NewLine +
                    "Local only; not uploaded." + Environment.NewLine + Environment.NewLine,
                    Encoding.UTF8);
                UiLog("Debug logging enabled");
                OpenLogBtn.IsEnabled = true;
                CopyLogBtn.IsEnabled = true;
                StatusText.Text = "Debug logging ON\n" + _lastLog;
            }
            else
            {
                UiLog("Debug logging disabled");
                StatusText.Text = "Debug logging OFF";
            }
        }

        private void OpenLog_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrEmpty(_lastLog) || !File.Exists(_lastLog))
            {
                MessageBox.Show("No debug log yet. Enable Debug logging first.", "Debug log");
                return;
            }
            Process.Start("explorer.exe", "/select,\"" + _lastLog + "\"");
        }

        private void CopyLog_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrEmpty(_lastLog))
            {
                MessageBox.Show("No debug log path yet.", "Debug log");
                return;
            }
            Clipboard.SetText(_lastLog);
            StatusText.Text = "Copied log path:\n" + _lastLog;
        }

        private void DropZone_DragOver(object sender, DragEventArgs e)
        {
            e.Effects = e.Data.GetDataPresent(DataFormats.FileDrop) ? DragDropEffects.Copy : DragDropEffects.None;
            e.Handled = true;
        }

        private void DropZone_Drop(object sender, DragEventArgs e)
        {
            if (_busy) return;
            if (!e.Data.GetDataPresent(DataFormats.FileDrop)) return;
            var files = (string[])e.Data.GetData(DataFormats.FileDrop);
            if (files != null && files.Length > 0) StartExport(files[0]);
        }

        private void DropZone_Click(object sender, MouseButtonEventArgs e)
        {
            if (_busy) return;
            var dlg = new Microsoft.Win32.OpenFileDialog
            {
                Filter = "Video|*.mov;*.mp4;*.m4v;*.avi;*.webm|All|*.*"
            };
            if (dlg.ShowDialog() == true) StartExport(dlg.FileName);
        }

        private void ChangeOut_Click(object sender, RoutedEventArgs e)
        {
            MessageBox.Show(
                "Set the output folder path in the text box.\nDefault: Videos\\AgentVideoParse",
                "Output folder");
        }

        private void StartExport(string path)
        {
            _busy = true;
            RevealBtn.IsEnabled = false;
            CopyBtn.IsEnabled = false;
            StatusText.Text = "Processing: " + Path.GetFileName(path) + "…";
            UiLog("StartExport path=" + path);

            bool debug = DebugCheck.IsChecked == true;
            string logPath = _lastLog;

            System.Threading.ThreadPool.QueueUserWorkItem(_ =>
            {
                try
                {
                    var root = OutputRootBox.Text.Trim();
                    Directory.CreateDirectory(root);
                    var outDir = Path.Combine(root, "export-" + DateTime.Now.ToString("yyyyMMdd-HHmmss"));
                    Directory.CreateDirectory(outDir);
                    var repo = FindRepoRoot();
                    var psi = new ProcessStartInfo
                    {
                        FileName = "python",
                        Arguments = "-m avp export \"" + path + "\" -o \"" + outDir + "\"",
                        WorkingDirectory = repo,
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        CreateNoWindow = true
                    };
                    psi.Environment["PYTHONPATH"] = Path.Combine(repo, "shared", "core") + ";" + repo;
                    if (debug && !string.IsNullOrEmpty(logPath))
                    {
                        psi.Environment["AVP_DEBUG"] = "1";
                        psi.Environment["AVP_DEBUG_LOG"] = logPath;
                    }
                    var p = Process.Start(psi);
                    var stdout = p.StandardOutput.ReadToEnd();
                    var stderr = p.StandardError.ReadToEnd();
                    p.WaitForExit();
                    Dispatcher.Invoke(() =>
                    {
                        _busy = false;
                        if (p.ExitCode == 0)
                        {
                            var dir = stdout.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries)[0];
                            _lastOut = dir;
                            StatusText.Text = "Wrote screenshots to:\n" + dir +
                                (debug && !string.IsNullOrEmpty(logPath) ? "\nDebug log: " + logPath : "");
                            RevealBtn.IsEnabled = true;
                            CopyBtn.IsEnabled = true;
                            UiLog("export success dir=" + dir);
                        }
                        else
                        {
                            StatusText.Text = string.IsNullOrWhiteSpace(stderr) ? stdout : stderr;
                            UiLog("export failed exit=" + p.ExitCode + " err=" + StatusText.Text);
                            var msg = StatusText.Text;
                            if (debug && !string.IsNullOrEmpty(logPath))
                                msg += "\n\nDebug log: " + logPath;
                            MessageBox.Show(msg, "AgentVideoParse");
                        }
                    });
                }
                catch (Exception ex)
                {
                    Dispatcher.Invoke(() =>
                    {
                        _busy = false;
                        StatusText.Text = ex.Message;
                        UiLog("export exception " + ex);
                        MessageBox.Show(ex.Message, "AgentVideoParse");
                    });
                }
            });
        }

        private static string FindRepoRoot()
        {
            var dir = new DirectoryInfo(AppDomain.CurrentDomain.BaseDirectory);
            while (dir != null)
            {
                if (Directory.Exists(Path.Combine(dir.FullName, "shared", "core", "avp")))
                    return dir.FullName;
                dir = dir.Parent;
            }
            return Directory.GetCurrentDirectory();
        }

        private void Reveal_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrEmpty(_lastOut)) return;
            Process.Start("explorer.exe", _lastOut);
        }

        private void Copy_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrEmpty(_lastOut)) return;
            Clipboard.SetText(_lastOut);
            StatusText.Text = "Copied path:\n" + _lastOut;
        }
    }
}
