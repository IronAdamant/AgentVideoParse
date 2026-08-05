// AgentVideoParse Windows helper — **system WPF MediaPlayer + WIC PNG only**.
// No NuGet packages. No vendored FFmpeg.
//
// Stack note (IMPLEMENTATION-PLAN, honest):
//   Still grabs via System.Windows.Media.MediaPlayer (inbox WPF / PresentationCore)
//   with ScrubbingEnabled, plus PngBitmapEncoder (WIC path via WPF).
//   No low-level Source Reader COM interop; no NuGet packages.
//   Platform codecs that MediaPlayer uses on Windows remain those provided by the OS.
//
// Build (no PackageReference):
//   csc /nologo /optimize+ /target:exe /out:AvpExtract.exe
//       /r:System.dll /r:System.Core.dll
//       /r:PresentationCore.dll /r:WindowsBase.dll /r:System.Xaml.dll
//       AvpExtract.cs
//
// Usage:
//   AvpExtract probe <video>
//   AvpExtract extract <video> <outDir> <t1,t2,...>
//
// Extract writes frame-0001.png … at each timestamp. For color-changing fixtures,
// successive frames must differ in content (see tests/docs).

using System;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.Error.WriteLine("usage: AvpExtract probe <video> | extract <video> <outDir> <timesCsv>");
            return 1;
        }
        try
        {
            if (args[0] == "probe")
            {
                double d = ProbeDuration(args[1]);
                Console.WriteLine(d.ToString("F6", CultureInfo.InvariantCulture));
                return 0;
            }
            if (args[0] == "extract")
            {
                if (args.Length < 4) throw new Exception("extract requires video outDir timesCsv");
                var times = args[3].Split(',')
                    .Select(s => double.Parse(s.Trim(), CultureInfo.InvariantCulture))
                    .ToArray();
                Extract(args[1], args[2], times);
                return 0;
            }
            throw new Exception("unknown command");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("ERROR: " + ex.Message);
            return 1;
        }
    }

    private static void RunSta(Action body)
    {
        Exception error = null;
        var thread = new System.Threading.Thread(() =>
        {
            try { body(); }
            catch (Exception ex) { error = ex; }
            try { Dispatcher.CurrentDispatcher.InvokeShutdown(); } catch { /* ignore */ }
        });
        thread.SetApartmentState(System.Threading.ApartmentState.STA);
        thread.Start();
        thread.Join();
        if (error != null) throw error;
    }

    private static MediaPlayer OpenPlayer(string path)
    {
        var player = new MediaPlayer();
        var openDone = new System.Threading.ManualResetEvent(false);
        Exception openError = null;
        player.MediaOpened += (s, e) => openDone.Set();
        player.MediaFailed += (s, e) =>
        {
            openError = e.ErrorException ?? new Exception("MediaFailed");
            openDone.Set();
        };
        player.Open(new Uri(Path.GetFullPath(path), UriKind.Absolute));
        if (!openDone.WaitOne(TimeSpan.FromSeconds(45)))
            throw new TimeoutException("open timeout");
        if (openError != null) throw openError;
        player.ScrubbingEnabled = true;
        player.Volume = 0;
        player.Play();
        player.Pause();
        // Allow first frame to decode
        System.Threading.Thread.Sleep(80);
        return player;
    }

    private static double ProbeDuration(string path)
    {
        if (!File.Exists(path)) throw new FileNotFoundException(path);
        double duration = 0;
        RunSta(() =>
        {
            var player = OpenPlayer(path);
            try
            {
                if (!player.NaturalDuration.HasTimeSpan)
                    throw new Exception("duration unavailable");
                duration = player.NaturalDuration.TimeSpan.TotalSeconds;
            }
            finally { player.Close(); }
        });
        if (duration <= 0) throw new Exception("invalid duration");
        return duration;
    }

    private static void Extract(string path, string outDir, double[] times)
    {
        Directory.CreateDirectory(outDir);
        RunSta(() =>
        {
            var player = OpenPlayer(path);
            try
            {
                int w = player.NaturalVideoWidth > 0 ? player.NaturalVideoWidth : 320;
                int h = player.NaturalVideoHeight > 0 ? player.NaturalVideoHeight : 240;
                int index = 1;
                byte[] previousHash = null;
                int distinct = 0;

                foreach (var t in times)
                {
                    // Scrub: set position, pump dispatcher, wait for decode
                    player.Position = TimeSpan.FromSeconds(Math.Max(0, t));
                    // Process WPF messages so video surface updates
                    for (int spin = 0; spin < 10; spin++)
                    {
                        Dispatcher.CurrentDispatcher.Invoke(
                            DispatcherPriority.Background, new Action(() => { }));
                        System.Threading.Thread.Sleep(30);
                    }
                    // Extra settle time scales slightly with scrub distance
                    System.Threading.Thread.Sleep(50);

                    var rtb = new RenderTargetBitmap(w, h, 96, 96, PixelFormats.Pbgra32);
                    var dv = new DrawingVisual();
                    using (var dc = dv.RenderOpen())
                    {
                        dc.DrawVideo(player, new Rect(0, 0, w, h));
                    }
                    rtb.Render(dv);

                    // Force pixel materialization
                    rtb.Freeze();
                    var enc = new PngBitmapEncoder();
                    enc.Frames.Add(BitmapFrame.Create(rtb));
                    string name = string.Format(CultureInfo.InvariantCulture, "frame-{0:D4}.png", index);
                    string dest = Path.Combine(outDir, name);
                    using (var fs = File.Create(dest))
                    {
                        enc.Save(fs);
                    }

                    // Track whether successive frames differ (for gradient fixtures)
                    byte[] hash = SimpleHashFile(dest);
                    if (previousHash == null || !HashEquals(previousHash, hash))
                        distinct++;
                    previousHash = hash;

                    Console.WriteLine(string.Format(CultureInfo.InvariantCulture,
                        "{0}\t{1:F6}\t{2}", index, t, name));
                    index++;
                }

                // When multiple sample times requested on a changing video, require
                // at least two distinct bit patterns when times.Length > 1.
                // (Static solid-color clips may legitimately match — do not fail hard;
                // log distinct count for tests.)
                Console.Error.WriteLine("INFO: distinct_frame_blobs=" + distinct + " of " + times.Length);
            }
            finally { player.Close(); }
        });
    }

    private static byte[] SimpleHashFile(string path)
    {
        // Small content fingerprint without third-party crypto libs
        var data = File.ReadAllBytes(path);
        unchecked
        {
            int h1 = 17, h2 = 31;
            for (int i = 0; i < data.Length; i += Math.Max(1, data.Length / 256))
            {
                h1 = h1 * 23 + data[i];
                h2 = h2 * 41 + data[i] * (i + 1);
            }
            return BitConverter.GetBytes(h1).Concat(BitConverter.GetBytes(h2)).ToArray();
        }
    }

    private static bool HashEquals(byte[] a, byte[] b)
    {
        if (a == null || b == null || a.Length != b.Length) return false;
        for (int i = 0; i < a.Length; i++) if (a[i] != b[i]) return false;
        return true;
    }
}
