#if os(iOS)
import AVFoundation

public enum AudioWaveformExtractor {
    /// Extract normalized amplitude samples from an audio file.
    /// Returns an array of Float values in 0...1 range.
    public static func extractSamples(from url: URL, count: Int = 60) async -> [Float] {
        await Task.detached {
            guard let file = try? AVAudioFile(forReading: url) else { return [Float](repeating: 0, count: count) }

            let length = file.length
            guard length > 0 else { return [Float](repeating: 0, count: count) }

            let format = file.processingFormat
            let samplesPerBucket = Int(length) / count

            guard samplesPerBucket > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(length))
            else { return [Float](repeating: 0, count: count) }

            do {
                try file.read(into: buffer)
            } catch {
                return [Float](repeating: 0, count: count)
            }

            guard let channelData = buffer.floatChannelData?[0] else {
                return [Float](repeating: 0, count: count)
            }

            let totalSamples = Int(buffer.frameLength)
            var result = [Float]()
            result.reserveCapacity(count)

            for i in 0..<count {
                let start = i * samplesPerBucket
                let end = min(start + samplesPerBucket, totalSamples)
                guard start < end else {
                    result.append(0)
                    continue
                }

                var sum: Float = 0
                for j in start..<end {
                    sum += abs(channelData[j])
                }
                result.append(sum / Float(end - start))
            }

            // Normalize to 0...1
            let peak = result.max() ?? 1
            guard peak > 0 else { return result }
            return result.map { $0 / peak }
        }.value
    }
}
#endif
