import Foundation

enum DurationStatus: String {
    case accepted
    case rejectedTooLong
    case rejectedInvalid
}

struct DurationDecision: Equatable {
    let status: DurationStatus
    let seconds: Double?
    let limit: Double

    var accepted: Bool { status == .accepted }
}

enum DurationGate {
    static func evaluate(durationSeconds: Double) -> DurationDecision {
        let limit = AVPConstants.durationLimitSeconds
        if durationSeconds.isNaN || durationSeconds.isInfinite || durationSeconds < 0 {
            return DurationDecision(status: .rejectedInvalid, seconds: durationSeconds, limit: limit)
        }
        if durationSeconds > limit {
            return DurationDecision(status: .rejectedTooLong, seconds: durationSeconds, limit: limit)
        }
        return DurationDecision(status: .accepted, seconds: durationSeconds, limit: limit)
    }
}
