import Foundation

enum FrameSampler {
    static func sampleTimes(
        durationSeconds: Double,
        fps: Double = AVPConstants.defaultSampleFPS,
        maxFrames: Int = AVPConstants.maxFrames
    ) -> [Double] {
        guard durationSeconds >= 0, fps > 0, maxFrames > 0 else { return [] }
        if durationSeconds == 0 { return [0] }

        let interval = 1.0 / fps
        var times: [Double] = []
        var t = 0.0
        while t < durationSeconds {
            times.append((t * 1_000_000).rounded() / 1_000_000)
            t += interval
            if times.count > maxFrames * 4 { break }
        }
        times = times.filter { $0 >= 0 && $0 <= durationSeconds }
        if times.isEmpty { times = [0] }
        if times.count > maxFrames {
            times = uniformThin(times, maxFrames: maxFrames)
        }
        var cleaned: [Double] = []
        for x in times {
            if cleaned.isEmpty || x > cleaned.last! {
                cleaned.append(x)
            }
        }
        return Array(cleaned.prefix(maxFrames))
    }

    private static func uniformThin(_ times: [Double], maxFrames: Int) -> [Double] {
        if maxFrames <= 1 { return [times[0]] }
        let n = times.count
        if n <= maxFrames { return times }
        var result: [Double] = []
        for i in 0..<maxFrames {
            let idx = Int((Double(i) * Double(n - 1) / Double(maxFrames - 1)).rounded())
            result.append(times[idx])
        }
        var out: [Double] = []
        for x in result {
            if out.isEmpty || x > out.last! { out.append(x) }
        }
        return out
    }
}
