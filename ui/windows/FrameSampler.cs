using System;
using System.Collections.Generic;

namespace AgentVideoParse
{
    internal static class FrameSampler
    {
        public static List<double> SampleTimes(
            double durationSeconds,
            double fps = AvpConstants.DefaultSampleFps,
            int maxFrames = AvpConstants.MaxFrames)
        {
            var times = new List<double>();
            if (durationSeconds < 0 || fps <= 0 || maxFrames <= 0)
                return times;
            if (durationSeconds == 0.0)
            {
                times.Add(0.0);
                return times;
            }

            double interval = 1.0 / fps;
            double t = 0.0;
            while (t < durationSeconds)
            {
                times.Add(Math.Round(t, 6));
                t += interval;
                if (times.Count > maxFrames * 4)
                    break;
            }

            if (times.Count > 0)
            {
                double end = Math.Max(0.0, durationSeconds - 0.001);
                if (end - times[times.Count - 1] >= interval * 0.45)
                    times.Add(Math.Round(end, 6));
            }

            times.RemoveAll(x => x < 0.0 || x > durationSeconds);
            if (times.Count == 0)
                times.Add(0.0);

            if (times.Count > maxFrames)
                times = UniformThin(times, maxFrames);

            var cleaned = new List<double>();
            foreach (var x in times)
            {
                if (cleaned.Count == 0 || x > cleaned[cleaned.Count - 1])
                    cleaned.Add(x);
            }
            if (cleaned.Count > maxFrames)
                cleaned = cleaned.GetRange(0, maxFrames);
            return cleaned;
        }

        private static List<double> UniformThin(List<double> times, int maxFrames)
        {
            if (maxFrames <= 1)
                return new List<double> { times[0] };
            int n = times.Count;
            if (n <= maxFrames)
                return times;
            var result = new List<double>();
            for (int i = 0; i < maxFrames; i++)
            {
                int idx = (int)Math.Round(i * (n - 1) / (double)(maxFrames - 1));
                result.Add(times[idx]);
            }
            var outList = new List<double>();
            foreach (var x in result)
            {
                if (outList.Count == 0 || x > outList[outList.Count - 1])
                    outList.Add(x);
            }
            return outList;
        }
    }
}
