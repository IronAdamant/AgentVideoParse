using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace AgentVideoParse
{
    internal sealed class ExportResult
    {
        public int FrameCount { get; set; }
        public double DurationSeconds { get; set; }
        public string OutputDirectory { get; set; }
        public string ManifestPath { get; set; }
    }

    internal sealed class ExportException : Exception
    {
        public string Code { get; private set; }

        public ExportException(string code, string message)
            : base(message)
        {
            Code = code;
        }
    }

    /// <summary>
    /// Full export path (parity with shared core + macOS app):
    /// probe → duration gate → sample → extract (WPF MediaPlayer) → JPEG stills → manifest.
    /// System frameworks only — no Python, no NuGet, no vendored FFmpeg.
    /// </summary>
    internal static class VideoExporter
    {
        public static string DefaultOutputRoot()
        {
            return Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.MyVideos),
                "AgentVideoParse");
        }

        public static string MakeRunDirectory(string outputRoot, string sourcePath)
        {
            string baseName = Path.GetFileNameWithoutExtension(sourcePath) ?? "video";
            var safeChars = new char[Math.Min(baseName.Length, 80)];
            int n = 0;
            foreach (char c in baseName)
            {
                if (n >= safeChars.Length) break;
                if (char.IsLetterOrDigit(c) || c == '-' || c == '_')
                    safeChars[n++] = c;
                else
                    safeChars[n++] = '_';
            }
            string safe = n > 0 ? new string(safeChars, 0, n) : "video";
            string stamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
            string path = Path.Combine(outputRoot, safe + "-" + stamp);
            Directory.CreateDirectory(path);
            return path;
        }

        public static ExportResult Export(
            string inputPath,
            string outputDirectory = null,
            string outputRoot = null,
            Action<int, int> progress = null,
            Func<bool> shouldCancel = null)
        {
            inputPath = Path.GetFullPath(inputPath);
            DebugLog.Log("export start input=" + inputPath);
            if (!File.Exists(inputPath))
                throw new ExportException("unsupported", "File not found: " + inputPath);

            double duration = ProbeDuration(inputPath);
            DebugLog.Log(string.Format(CultureInfo.InvariantCulture, "probe duration={0:F6}", duration));

            var decision = DurationDecision.Evaluate(duration);
            DebugLog.Log("gate status=" + decision.Status);
            if (decision.Status == DurationStatus.RejectedInvalid)
                throw new ExportException("unsupported", "Could not determine a valid video duration.");
            if (decision.Status == DurationStatus.RejectedTooLong)
            {
                throw new ExportException(
                    "too_long",
                    string.Format(CultureInfo.InvariantCulture,
                        "This video is {0:F2}s long. AgentVideoParse only accepts videos of {1:g} seconds or less " +
                        "(debugging sessions). No screenshots were created.",
                        duration, AvpConstants.DurationLimitSeconds));
            }

            bool removeOnFailure;
            if (!string.IsNullOrEmpty(outputDirectory))
            {
                outputDirectory = Path.GetFullPath(outputDirectory);
                Directory.CreateDirectory(outputDirectory);
                removeOnFailure = false;
            }
            else
            {
                string root = string.IsNullOrEmpty(outputRoot) ? DefaultOutputRoot() : outputRoot;
                Directory.CreateDirectory(root);
                outputDirectory = MakeRunDirectory(root, inputPath);
                removeOnFailure = true;
            }
            DebugLog.Log("output=" + outputDirectory);

            var times = FrameSampler.SampleTimes(duration);
            DebugLog.Log("sample_times count=" + times.Count);

            try
            {
                if (shouldCancel != null && shouldCancel())
                    throw new ExportException("cancelled", "Export cancelled. Incomplete output was removed.");

                if (progress != null) progress(0, times.Count);
                var actual = ExtractFrames(inputPath, outputDirectory, times, progress, shouldCancel);
                if (actual.Count == 0)
                    actual = new List<double>(times);

                var entries = new List<Tuple<int, double, string>>();
                for (int i = 0; i < actual.Count; i++)
                {
                    int idx = i + 1;
                    string name = ManifestWriter.FrameFilename(idx);
                    string fpath = Path.Combine(outputDirectory, name);
                    if (!File.Exists(fpath))
                        throw new ExportException("write_failed", "Expected frame file missing: " + name);
                    entries.Add(Tuple.Create(idx, actual[i], name));
                }

                string manifest = ManifestWriter.WriteManifest(
                    outputDirectory, inputPath, duration, entries);
                ManifestWriter.WriteAgentReadme(outputDirectory);
                DebugLog.Log("export success frames=" + entries.Count + " dir=" + outputDirectory);

                return new ExportResult
                {
                    FrameCount = entries.Count,
                    DurationSeconds = duration,
                    OutputDirectory = outputDirectory,
                    ManifestPath = manifest,
                };
            }
            catch (Exception)
            {
                CleanupPartial(outputDirectory, removeOnFailure);
                throw;
            }
        }

        private static void CleanupPartial(string outputDirectory, bool removeDirectory)
        {
            if (string.IsNullOrEmpty(outputDirectory) || !Directory.Exists(outputDirectory))
                return;
            try
            {
                if (removeDirectory)
                {
                    Directory.Delete(outputDirectory, true);
                    return;
                }
                foreach (var name in Directory.GetFiles(outputDirectory))
                {
                    string baseName = Path.GetFileName(name);
                    if (baseName.StartsWith("frame-", StringComparison.OrdinalIgnoreCase) ||
                        baseName == "MANIFEST.txt" ||
                        baseName == "README-FOR-AGENT.txt")
                    {
                        try { File.Delete(name); } catch { /* ignore */ }
                    }
                }
            }
            catch
            {
                /* ignore cleanup errors */
            }
        }

        private static List<double> ExtractFrames(
            string path,
            string outDir,
            IList<double> times,
            Action<int, int> progress,
            Func<bool> shouldCancel)
        {
            var actual = new List<double>();
            Directory.CreateDirectory(outDir);
            RunSta(() =>
            {
                // MediaElement hosted in a real (off-screen) window is far more reliable
                // for scrubbing than MediaPlayer + DrawVideo, which often freezes on frame 0
                // for H.264 screen recordings (all stills become identical).
                Window host = null;
                MediaElement media = null;
                try
                {
                    media = new MediaElement
                    {
                        LoadedBehavior = MediaState.Manual,
                        UnloadedBehavior = MediaState.Close,
                        ScrubbingEnabled = true,
                        Stretch = Stretch.Fill,
                        Volume = 0,
                        IsMuted = true,
                    };

                    host = new Window
                    {
                        Title = "AgentVideoParse capture",
                        WindowStyle = WindowStyle.None,
                        ShowInTaskbar = false,
                        ShowActivated = false,
                        ResizeMode = ResizeMode.NoResize,
                        // Park off-screen so nothing flashes for the user
                        Left = -32000,
                        Top = -32000,
                        Width = 64,
                        Height = 64,
                        Content = media,
                    };
                    host.Show();

                    var openDone = new ManualResetEvent(false);
                    Exception openError = null;
                    media.MediaOpened += (s, e) => openDone.Set();
                    media.MediaFailed += (s, e) =>
                    {
                        openError = e.ErrorException ?? new Exception("MediaFailed");
                        openDone.Set();
                    };

                    media.Source = new Uri(Path.GetFullPath(path), UriKind.Absolute);
                    media.Play();
                    media.Pause();

                    if (!WaitWithPump(openDone, TimeSpan.FromSeconds(45)))
                        throw new ExportException("unsupported", "open timeout");
                    if (openError != null)
                        throw new ExportException("unsupported", openError.Message);

                    int w = media.NaturalVideoWidth > 0 ? media.NaturalVideoWidth : 320;
                    int h = media.NaturalVideoHeight > 0 ? media.NaturalVideoHeight : 240;
                    // Size the visual to native video resolution so RenderTargetBitmap captures full frame
                    media.Width = w;
                    media.Height = h;
                    host.Width = w;
                    host.Height = h;
                    host.UpdateLayout();
                    PumpBriefly(120);

                    byte[] previousPixels = null;
                    int distinct = 0;

                    for (int i = 0; i < times.Count; i++)
                    {
                        if (shouldCancel != null && shouldCancel())
                            throw new ExportException("cancelled", "Export cancelled. Incomplete output was removed.");

                        double t = times[i];
                        SeekTo(media, t);

                        BitmapSource rtb = CaptureFrame(media, w, h);

                        // If scrub did not produce a new image, nudge with a short play and recapture
                        byte[] pixels = CopyPixels(rtb);
                        if (previousPixels != null && BytesEqual(previousPixels, pixels) && i > 0)
                        {
                            DebugLog.Log(string.Format(CultureInfo.InvariantCulture,
                                "frame {0} identical after seek t={1:F3}; retry with play-nudge", i + 1, t));
                            media.Play();
                            PumpBriefly(180);
                            media.Pause();
                            PumpBriefly(80);
                            // Re-seek in case play advanced past target
                            SeekTo(media, t);
                            rtb = CaptureFrame(media, w, h);
                            pixels = CopyPixels(rtb);
                        }

                        if (previousPixels == null || !BytesEqual(previousPixels, pixels))
                            distinct++;
                        previousPixels = pixels;

                        BitmapSource frame = rtb;
                        int longEdge = Math.Max(w, h);
                        if (longEdge > AvpConstants.MaxLongEdge && AvpConstants.MaxLongEdge > 0)
                        {
                            double scale = AvpConstants.MaxLongEdge / (double)longEdge;
                            int nw = Math.Max(1, (int)Math.Round(w * scale));
                            int nh = Math.Max(1, (int)Math.Round(h * scale));
                            frame = new TransformedBitmap(rtb, new ScaleTransform(nw / (double)w, nh / (double)h));
                            frame.Freeze();
                        }

                        var converted = new FormatConvertedBitmap(frame, PixelFormats.Bgr24, null, 0);
                        converted.Freeze();

                        string name = ManifestWriter.FrameFilename(i + 1);
                        string dest = Path.Combine(outDir, name);
                        var enc = new JpegBitmapEncoder();
                        enc.QualityLevel = AvpConstants.JpegQuality;
                        enc.Frames.Add(BitmapFrame.Create(converted));
                        using (var fs = File.Create(dest))
                        {
                            enc.Save(fs);
                        }

                        actual.Add(t);
                        if (progress != null)
                            progress(i + 1, times.Count);
                    }

                    DebugLog.Log("distinct_frame_blobs=" + distinct + " of " + times.Count);
                    if (times.Count > 3 && distinct < 2)
                    {
                        throw new ExportException(
                            "write_failed",
                            "Could not extract distinct video frames (decoder scrubbing failed). " +
                            "Try re-exporting the clip as H.264 .mp4, or use a shorter screen recording.");
                    }
                }
                finally
                {
                    try
                    {
                        if (media != null)
                        {
                            media.Stop();
                            media.Close();
                            media.Source = null;
                        }
                    }
                    catch { /* ignore */ }
                    try
                    {
                        if (host != null)
                            host.Close();
                    }
                    catch { /* ignore */ }
                }
            });
            return actual;
        }

        private static void SeekTo(MediaElement media, double seconds)
        {
            var target = TimeSpan.FromSeconds(Math.Max(0, seconds));
            media.Pause();
            media.Position = target;
            // Brief play forces many H.264 pipelines to decode the new keyframe/GOP
            media.Play();
            PumpBriefly(120);
            media.Pause();
            // Snap back in case play drifted
            media.Position = target;
            PumpBriefly(100);

            // Wait until reported position is near the target (best-effort)
            var sw = System.Diagnostics.Stopwatch.StartNew();
            while (sw.ElapsedMilliseconds < 800)
            {
                PumpOnce();
                double pos = media.Position.TotalSeconds;
                if (Math.Abs(pos - seconds) < 0.35)
                    break;
            }
            PumpBriefly(40);
        }

        private static BitmapSource CaptureFrame(MediaElement media, int w, int h)
        {
            media.UpdateLayout();
            PumpOnce();
            var rtb = new RenderTargetBitmap(w, h, 96, 96, PixelFormats.Pbgra32);
            rtb.Render(media);
            rtb.Freeze();
            return rtb;
        }

        private static byte[] CopyPixels(BitmapSource src)
        {
            int stride = (src.PixelWidth * src.Format.BitsPerPixel + 7) / 8;
            // Downsample fingerprint: every 16th row, full width — cheap distinctness check
            int step = Math.Max(1, src.PixelHeight / 32);
            var buf = new byte[stride * ((src.PixelHeight + step - 1) / step)];
            int o = 0;
            var row = new byte[stride];
            for (int y = 0; y < src.PixelHeight; y += step)
            {
                src.CopyPixels(new Int32Rect(0, y, src.PixelWidth, 1), row, stride, 0);
                Buffer.BlockCopy(row, 0, buf, o, stride);
                o += stride;
            }
            if (o < buf.Length)
            {
                var trimmed = new byte[o];
                Buffer.BlockCopy(buf, 0, trimmed, 0, o);
                return trimmed;
            }
            return buf;
        }

        private static bool BytesEqual(byte[] a, byte[] b)
        {
            if (a == null || b == null || a.Length != b.Length)
                return false;
            for (int i = 0; i < a.Length; i++)
            {
                if (a[i] != b[i])
                    return false;
            }
            return true;
        }

        public static double ProbeDuration(string path)
        {
            if (!File.Exists(path))
                throw new ExportException("unsupported", "File not found: " + path);
            double duration = 0;
            RunSta(() =>
            {
                var player = new MediaPlayer();
                try
                {
                    var openDone = new ManualResetEvent(false);
                    Exception openError = null;
                    player.MediaOpened += (s, e) => openDone.Set();
                    player.MediaFailed += (s, e) =>
                    {
                        openError = e.ErrorException ?? new Exception("MediaFailed");
                        openDone.Set();
                    };
                    player.Open(new Uri(Path.GetFullPath(path), UriKind.Absolute));
                    if (!WaitWithPump(openDone, TimeSpan.FromSeconds(45)))
                        throw new ExportException("unsupported", "open timeout");
                    if (openError != null)
                        throw new ExportException("unsupported", openError.Message);
                    if (!player.NaturalDuration.HasTimeSpan)
                        throw new ExportException("unsupported", "duration unavailable");
                    duration = player.NaturalDuration.TimeSpan.TotalSeconds;
                }
                finally
                {
                    player.Close();
                }
            });
            if (duration <= 0)
                throw new ExportException("unsupported", "invalid duration");
            return duration;
        }

        /// <summary>
        /// Pump the STA dispatcher until <paramref name="done"/> is signaled or timeout.
        /// MediaPlayer raises MediaOpened on the creating thread; blocking WaitOne without
        /// PushFrame deadlocks.
        /// </summary>
        private static bool WaitWithPump(WaitHandle done, TimeSpan timeout)
        {
            var sw = System.Diagnostics.Stopwatch.StartNew();
            while (!done.WaitOne(0))
            {
                if (sw.Elapsed >= timeout)
                    return false;
                PumpOnce();
            }
            return true;
        }

        private static void PumpBriefly(int milliseconds)
        {
            var sw = System.Diagnostics.Stopwatch.StartNew();
            while (sw.ElapsedMilliseconds < milliseconds)
                PumpOnce();
        }

        private static void PumpOnce()
        {
            // Nested message loop so MediaOpened / decode callbacks can run on this STA thread.
            var frame = new DispatcherFrame();
            Dispatcher.CurrentDispatcher.BeginInvoke(
                DispatcherPriority.Background,
                new DispatcherOperationCallback(delegate(object f)
                {
                    ((DispatcherFrame)f).Continue = false;
                    return null;
                }),
                frame);
            Dispatcher.PushFrame(frame);
            Thread.Sleep(10);
        }

        /// <summary>
        /// Always use a dedicated STA thread with its own Dispatcher.
        /// Never run MediaPlayer work on the WPF UI thread while blocking it.
        /// </summary>
        private static void RunSta(Action body)
        {
            Exception error = null;
            var thread = new Thread(() =>
            {
                try
                {
                    // Touch CurrentDispatcher so this STA thread has a message queue.
                    var unused = Dispatcher.CurrentDispatcher;
                    body();
                }
                catch (Exception ex)
                {
                    error = ex;
                }
                try
                {
                    Dispatcher.CurrentDispatcher.InvokeShutdown();
                }
                catch { /* ignore */ }
            });
            thread.SetApartmentState(ApartmentState.STA);
            thread.IsBackground = true;
            thread.Name = "AVP-Media";
            thread.Start();
            // Media work is bounded by open timeout + per-frame settles; allow headroom.
            if (!thread.Join(TimeSpan.FromMinutes(10)))
                throw new ExportException("unsupported", "Media worker timed out.");
            if (error != null)
                throw error;
        }
    }
}
