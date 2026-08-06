using System;
using System.IO;
using System.Text;

namespace AgentVideoParse
{
    /// <summary>Optional local debug log (never uploaded).</summary>
    internal static class DebugLog
    {
        private static readonly object Gate = new object();
        private static string _path;
        private static bool _enabled;

        public static string LogPath
        {
            get { return _path; }
        }

        public static string DefaultLogDir()
        {
            return Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.MyVideos),
                "AgentVideoParse", "logs");
        }

        public static string SetEnabled(bool on)
        {
            lock (Gate)
            {
                _enabled = on;
                if (!on)
                    return _path;
                var dir = DefaultLogDir();
                Directory.CreateDirectory(dir);
                _path = Path.Combine(dir,
                    "agentvideoparse-debug-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".log");
                File.WriteAllText(_path,
                    "=== AgentVideoParse Windows GUI debug log " +
                    DateTime.UtcNow.ToString("o") + " ===" + Environment.NewLine +
                    "Local only; not uploaded." + Environment.NewLine + Environment.NewLine,
                    new UTF8Encoding(false));
                return _path;
            }
        }

        public static void Log(string message)
        {
            lock (Gate)
            {
                if (!_enabled || string.IsNullOrEmpty(_path))
                    return;
                try
                {
                    File.AppendAllText(_path,
                        "[" + DateTime.UtcNow.ToString("o") + "] " + message + Environment.NewLine,
                        new UTF8Encoding(false));
                }
                catch
                {
                    /* ignore log IO */
                }
            }
        }
    }
}
