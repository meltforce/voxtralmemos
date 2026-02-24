#if os(iOS)
import Foundation
import AVFoundation

@MainActor
public final class AudioRecorderService: NSObject, ObservableObject {
    @Published public var isRecording = false
    @Published public var isPaused = false
    @Published public var elapsedTime: TimeInterval = 0
    @Published public var currentLevel: Float = 0
    @Published public var levelSamples: [Float] = []

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var startTime: Date?
    private var pausedElapsed: TimeInterval = 0
    private let maxSamples = 30

    public override init() {
        super.init()
    }

    public func startRecording(to fileURL: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        isRecording = true
        startTime = Date()
        elapsedTime = 0

        levelSamples = []
        currentLevel = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startTime = self.startTime else { return }
                self.elapsedTime = Date().timeIntervalSince(startTime)

                self.audioRecorder?.updateMeters()
                let dB = self.audioRecorder?.averagePower(forChannel: 0) ?? -60
                let linear = max(0, min(1, (dB + 60) / 60))
                self.currentLevel = linear
                self.levelSamples.append(linear)
                if self.levelSamples.count > self.maxSamples {
                    self.levelSamples.removeFirst(self.levelSamples.count - self.maxSamples)
                }
            }
        }
    }

    public func pauseRecording() {
        guard isRecording, !isPaused else { return }
        audioRecorder?.pause()
        isPaused = true
        pausedElapsed = elapsedTime
        timer?.invalidate()
        timer = nil
        currentLevel = 0
    }

    public func resumeRecording() {
        guard isRecording, isPaused else { return }
        audioRecorder?.record()
        isPaused = false
        startTime = Date().addingTimeInterval(-pausedElapsed)

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startTime = self.startTime else { return }
                self.elapsedTime = Date().timeIntervalSince(startTime)

                self.audioRecorder?.updateMeters()
                let dB = self.audioRecorder?.averagePower(forChannel: 0) ?? -60
                let linear = max(0, min(1, (dB + 60) / 60))
                self.currentLevel = linear
                self.levelSamples.append(linear)
                if self.levelSamples.count > self.maxSamples {
                    self.levelSamples.removeFirst(self.levelSamples.count - self.maxSamples)
                }
            }
        }
    }

    public func stopRecording() -> TimeInterval {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil

        let duration = elapsedTime
        isRecording = false
        isPaused = false
        elapsedTime = 0
        startTime = nil
        pausedElapsed = 0
        audioRecorder = nil
        currentLevel = 0
        levelSamples = []

        try? AVAudioSession.sharedInstance().setActive(false)
        return duration
    }

    public static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
#endif
