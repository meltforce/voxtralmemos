#if os(iOS)
import Foundation
import AVFoundation

@MainActor
public final class AudioRecorderService: NSObject, ObservableObject {
    @Published public var isRecording = false
    @Published public var elapsedTime: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var startTime: Date?

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
        audioRecorder?.record()

        isRecording = true
        startTime = Date()
        elapsedTime = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startTime = self.startTime else { return }
                self.elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }

    public func stopRecording() -> TimeInterval {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil

        let duration = elapsedTime
        isRecording = false
        elapsedTime = 0
        startTime = nil
        audioRecorder = nil

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
