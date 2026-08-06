using System;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Input;
using Microsoft.Win32;

namespace AgentVideoParse
{
    public partial class MainWindow : Window
    {
        private string _lastOut;
        private bool _busy;

        public MainWindow()
        {
            InitializeComponent();
            DisclaimerText.Text = AvpConstants.Disclaimer;
            OutputRootBox.Text = VideoExporter.DefaultOutputRoot();
        }

        private void UiLog(string message)
        {
            DebugLog.Log(message);
        }

        private void DebugCheck_Changed(object sender, RoutedEventArgs e)
        {
            if (DebugCheck.IsChecked == true)
            {
                string path = DebugLog.SetEnabled(true);
                UiLog("Debug logging enabled");
                OpenLogBtn.IsEnabled = true;
                CopyLogBtn.IsEnabled = true;
                StatusText.Text = "Debug logging ON\n" + path;
            }
            else
            {
                UiLog("Debug logging disabled");
                DebugLog.SetEnabled(false);
                StatusText.Text = "Debug logging OFF";
            }
        }

        private void OpenLog_Click(object sender, RoutedEventArgs e)
        {
            string path = DebugLog.LogPath;
            if (string.IsNullOrEmpty(path) || !File.Exists(path))
            {
                MessageBox.Show("No debug log yet. Enable Debug logging first.", "Debug log");
                return;
            }
            Process.Start("explorer.exe", "/select,\"" + path + "\"");
        }

        private void CopyLog_Click(object sender, RoutedEventArgs e)
        {
            string path = DebugLog.LogPath;
            if (string.IsNullOrEmpty(path))
            {
                MessageBox.Show("No debug log path yet.", "Debug log");
                return;
            }
            Clipboard.SetText(path);
            StatusText.Text = "Copied log path:\n" + path;
        }

        private void DropZone_DragOver(object sender, DragEventArgs e)
        {
            e.Effects = e.Data.GetDataPresent(DataFormats.FileDrop)
                ? DragDropEffects.Copy
                : DragDropEffects.None;
            e.Handled = true;
        }

        private void DropZone_Drop(object sender, DragEventArgs e)
        {
            if (_busy) return;
            if (!e.Data.GetDataPresent(DataFormats.FileDrop)) return;
            var files = (string[])e.Data.GetData(DataFormats.FileDrop);
            if (files != null && files.Length > 0)
                StartExport(files[0]);
        }

        private void DropZone_Click(object sender, MouseButtonEventArgs e)
        {
            if (_busy) return;
            var dlg = new OpenFileDialog
            {
                Filter = "Video|*.mov;*.mp4;*.m4v;*.avi;*.webm|All|*.*",
                Title = "Choose a debug video (30 seconds or shorter)",
            };
            if (dlg.ShowDialog() == true)
                StartExport(dlg.FileName);
        }

        private void ChangeOut_Click(object sender, RoutedEventArgs e)
        {
            // Modern Explorer-style "Select Folder" dialog (Vista+), not the old tree picker.
            string current = OutputRootBox.Text.Trim();
            if (!Directory.Exists(current))
            {
                string def = VideoExporter.DefaultOutputRoot();
                try { Directory.CreateDirectory(def); } catch { /* ignore */ }
                current = Directory.Exists(def) ? def : current;
            }

            var helper = new System.Windows.Interop.WindowInteropHelper(this);
            string path = FolderPicker.Show(
                helper.Handle,
                "Choose where screenshot folders will be saved",
                current);

            if (!string.IsNullOrWhiteSpace(path))
            {
                OutputRootBox.Text = path;
                UiLog("output root " + path);
                StatusText.Text = "Output folder:\n" + path;
            }
        }

        private void StartExport(string path)
        {
            _busy = true;
            RevealBtn.IsEnabled = false;
            CopyBtn.IsEnabled = false;
            StatusText.Text = "Processing: " + Path.GetFileName(path) + "…";
            UiLog("StartExport path=" + path);

            string outputRoot = OutputRootBox.Text.Trim();
            if (string.IsNullOrEmpty(outputRoot))
                outputRoot = VideoExporter.DefaultOutputRoot();

            System.Threading.ThreadPool.QueueUserWorkItem(_ =>
            {
                try
                {
                    var result = VideoExporter.Export(
                        path,
                        outputDirectory: null,
                        outputRoot: outputRoot,
                        progress: (i, n) =>
                        {
                            Dispatcher.BeginInvoke(new Action(() =>
                            {
                                StatusText.Text = string.Format(
                                    "Extracting frames… {0}/{1}", i, n);
                            }));
                        });

                    Dispatcher.Invoke(() =>
                    {
                        _busy = false;
                        _lastOut = result.OutputDirectory;
                        string logNote = "";
                        if (DebugCheck.IsChecked == true && !string.IsNullOrEmpty(DebugLog.LogPath))
                            logNote = "\nDebug log: " + DebugLog.LogPath;
                        StatusText.Text =
                            "Wrote " + result.FrameCount + " screenshots to:\n" +
                            result.OutputDirectory + logNote;
                        RevealBtn.IsEnabled = true;
                        CopyBtn.IsEnabled = true;
                        UiLog("export success dir=" + result.OutputDirectory);
                    });
                }
                catch (Exception ex)
                {
                    Dispatcher.Invoke(() =>
                    {
                        _busy = false;
                        string msg = ex.Message;
                        StatusText.Text = msg;
                        UiLog("export failed " + ex);
                        if (DebugCheck.IsChecked == true && !string.IsNullOrEmpty(DebugLog.LogPath))
                            msg += "\n\nDebug log: " + DebugLog.LogPath;
                        MessageBox.Show(msg, "AgentVideoParse");
                    });
                }
            });
        }

        private void Reveal_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrEmpty(_lastOut)) return;
            if (Directory.Exists(_lastOut))
                Process.Start("explorer.exe", _lastOut);
            else
                Process.Start("explorer.exe", "/select,\"" + _lastOut + "\"");
        }

        private void Copy_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrEmpty(_lastOut)) return;
            Clipboard.SetText(_lastOut);
            StatusText.Text = "Copied path:\n" + _lastOut;
        }
    }
}
