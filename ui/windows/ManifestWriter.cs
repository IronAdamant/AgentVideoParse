using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;

namespace AgentVideoParse
{
    internal static class ManifestWriter
    {
        public static string FrameFilename(int index)
        {
            return string.Format(CultureInfo.InvariantCulture,
                "frame-{0:D4}.{1}", index, AvpConstants.FrameExtension);
        }

        public static string WriteManifest(
            string outputDirectory,
            string sourcePath,
            double durationSeconds,
            IList<Tuple<int, double, string>> entries,
            double sampleFps = AvpConstants.DefaultSampleFps)
        {
            string path = Path.Combine(outputDirectory, "MANIFEST.txt");
            string generated = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ", CultureInfo.InvariantCulture);
            var sb = new StringBuilder();
            sb.AppendLine("# AgentVideoParse manifest");
            sb.AppendLine("# purpose: debugging / agent UI review only");
            sb.AppendLine("# source: " + sourcePath);
            sb.AppendLine(string.Format(CultureInfo.InvariantCulture, "# duration_seconds: {0:F6}", durationSeconds));
            sb.AppendLine(string.Format(CultureInfo.InvariantCulture, "# max_allowed_seconds: {0:g}", AvpConstants.DurationLimitSeconds));
            sb.AppendLine(string.Format(CultureInfo.InvariantCulture, "# sample_fps: {0:g}", sampleFps));
            sb.AppendLine("# frame_count: " + entries.Count);
            sb.AppendLine("# max_frames: " + AvpConstants.MaxFrames);
            sb.AppendLine("# image_format: " + AvpConstants.FrameExtension);
            sb.AppendLine("# max_long_edge: " + AvpConstants.MaxLongEdge);
            sb.AppendLine("# jpeg_quality: " + AvpConstants.JpegQuality);
            sb.AppendLine("# platform: windows-app");
            sb.AppendLine("# generated_at: " + generated);
            sb.AppendLine();
            sb.AppendLine("index\ttimestamp_seconds\tfilename");
            foreach (var e in entries)
            {
                sb.AppendLine(string.Format(CultureInfo.InvariantCulture,
                    "{0}\t{1:F3}\t{2}", e.Item1, e.Item2, e.Item3));
            }
            File.WriteAllText(path, sb.ToString(), new UTF8Encoding(false));
            return path;
        }

        public static string WriteAgentReadme(string outputDirectory)
        {
            string path = Path.Combine(outputDirectory, "README-FOR-AGENT.txt");
            string text =
                "AgentVideoParse output\n" +
                "======================\n\n" +
                "These ordered screenshots were extracted from a short debug video " +
                "(maximum 60 seconds). This folder is for AI/agent UI debugging only.\n\n" +
                "Read MANIFEST.txt for index → timestamp → filename mapping.\n" +
                "Frames are named frame-0001." + AvpConstants.FrameExtension +
                ", … in time order (agent-friendly JPEG, long edge ≤ " +
                AvpConstants.MaxLongEdge + "px).\n";
            File.WriteAllText(path, text, new UTF8Encoding(false));
            return path;
        }
    }
}
