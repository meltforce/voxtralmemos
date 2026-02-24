import SwiftUI
import VoxtralCore

struct RecordingOverlayView: View {
    @ObservedObject var recorder: AudioRecorderService
    var onRecord: () -> Void
    var onStop: () -> Void

    @State private var morphProgress: CGFloat = 0
    @State private var contentOpacity: CGFloat = 0
    @State private var stopPulse = false

    private let idleWidth: CGFloat = 120
    private let barHeight: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            let barWidth = max(idleWidth, geo.size.width - 32)
            let currentWidth = idleWidth + (barWidth - idleWidth) * morphProgress

            ZStack {
                // Background capsule — layered for smooth color transition
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(Color(hex: 0xFF6B6B).opacity(0.15 * morphProgress))
                    )
                    .overlay(
                        Capsule()
                            .fill(Color(hex: 0x007AFF).opacity(1 - morphProgress))
                    )
                    .frame(width: currentWidth, height: barHeight)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)

                // Idle content (record button)
                idleContent
                    .opacity(1 - contentOpacity)
                    .allowsHitTesting(morphProgress < 0.5)

                // Recording content
                recordingContent(barWidth: barWidth)
                    .frame(width: barWidth - 32)
                    .opacity(contentOpacity)
                    .allowsHitTesting(morphProgress > 0.5)
            }
            .frame(width: geo.size.width, height: barHeight)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .frame(height: barHeight)
        .padding(.bottom, 16)
        .onChange(of: recorder.isRecording) { _, isRecording in
            if isRecording {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    morphProgress = 1
                }
                withAnimation(.easeOut(duration: 0.2).delay(0.15)) {
                    contentOpacity = 1
                }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    stopPulse = true
                }
            } else {
                stopPulse = false
                withAnimation(.easeOut(duration: 0.15)) {
                    contentOpacity = 0
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.12)) {
                    morphProgress = 0
                }
            }
        }
    }

    // MARK: - Idle Content

    private var idleContent: some View {
        Button(action: onRecord) {
            HStack(spacing: 6) {
                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
                Text("Record")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(PressScaleStyle(scale: 0.92))
    }

    // MARK: - Recording Content

    private func recordingContent(barWidth: CGFloat) -> some View {
        HStack(spacing: 12) {
            WaveformView(samples: recorder.levelSamples)
                .frame(width: 80, height: 28)

            Spacer()

            // Pause / Resume
            Button {
                if recorder.isPaused {
                    recorder.resumeRecording()
                } else {
                    recorder.pauseRecording()
                }
            } label: {
                Image(systemName: recorder.isPaused ? "mic.fill" : "pause.fill")
                    .font(.body)
                    .foregroundStyle(recorder.isPaused ? Color(hex: 0x007AFF) : .primary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressScaleStyle(scale: 0.9))

            // Stop button
            Button(action: onStop) {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0xFF3B30))
                        .frame(width: 36, height: 36)
                        .scaleEffect(stopPulse ? 1.05 : 1.0)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white)
                        .frame(width: 12, height: 12)
                }
            }
            .buttonStyle(PressScaleStyle(scale: 0.88))

            Spacer()

            Text(formatTime(recorder.elapsedTime))
                .font(.body.monospacedDigit())
                .foregroundStyle(.primary)
                .frame(width: 54, alignment: .trailing)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Waveform

private struct WaveformView: View {
    let samples: [Float]
    private let barCount = 20

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                let value = sampleValue(at: index)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(hex: 0xFF3B30).opacity(0.7))
                    .frame(width: 2.5, height: max(3, CGFloat(value) * 28))
                    .animation(.easeOut(duration: 0.08), value: value)
            }
        }
    }

    private func sampleValue(at index: Int) -> Float {
        guard !samples.isEmpty else { return 0.1 }
        let sampleIndex = Int(Float(index) / Float(barCount) * Float(samples.count))
        let clampedIndex = min(sampleIndex, samples.count - 1)
        return max(0.1, samples[clampedIndex])
    }
}

// MARK: - Press Scale Button Style

private struct PressScaleStyle: ButtonStyle {
    let scale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
