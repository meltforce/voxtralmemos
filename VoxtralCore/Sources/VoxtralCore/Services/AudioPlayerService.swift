#if os(iOS)
import Foundation
import AVFoundation

@MainActor
public final class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published public var isPlaying = false
    @Published public var currentTime: TimeInterval = 0
    @Published public var duration: TimeInterval = 0

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    public override init() {
        super.init()
    }

    public func play(url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        duration = audioPlayer?.duration ?? 0
        audioPlayer?.play()
        isPlaying = true

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = self.audioPlayer?.currentTime ?? 0
            }
        }
    }

    public func resume() {
        audioPlayer?.play()
        isPlaying = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = self.audioPlayer?.currentTime ?? 0
            }
        }
    }

    public func pause() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
    }

    public func stop() {
        audioPlayer?.stop()
        isPlaying = false
        currentTime = 0
        timer?.invalidate()
        timer = nil
        audioPlayer = nil
    }

    public func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0
            self.timer?.invalidate()
            self.timer = nil
        }
    }
}
#endif
