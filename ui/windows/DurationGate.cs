using System;

namespace AgentVideoParse
{
    internal enum DurationStatus
    {
        Accepted,
        RejectedTooLong,
        RejectedInvalid,
    }

    internal sealed class DurationDecision
    {
        public DurationStatus Status { get; private set; }
        public double? Seconds { get; private set; }
        public double Limit { get; private set; }

        public bool Accepted
        {
            get { return Status == DurationStatus.Accepted; }
        }

        public static DurationDecision Evaluate(double durationSeconds)
        {
            var limit = AvpConstants.DurationLimitSeconds;
            if (double.IsNaN(durationSeconds) || double.IsInfinity(durationSeconds) || durationSeconds < 0.0)
            {
                return new DurationDecision
                {
                    Status = DurationStatus.RejectedInvalid,
                    Seconds = durationSeconds,
                    Limit = limit,
                };
            }
            if (durationSeconds > limit)
            {
                return new DurationDecision
                {
                    Status = DurationStatus.RejectedTooLong,
                    Seconds = durationSeconds,
                    Limit = limit,
                };
            }
            return new DurationDecision
            {
                Status = DurationStatus.Accepted,
                Seconds = durationSeconds,
                Limit = limit,
            };
        }
    }
}
