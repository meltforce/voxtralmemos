import Foundation
import SwiftData

public enum MemoStatus: String, Codable {
    case recording, transcribing, ready, failed
}

@Model
public final class Memo {
    public var id: UUID
    public var createdAt: Date
    public var duration: TimeInterval
    public var audioFileName: String
    public var transcript: String?
    public var language: String?
    public var status: MemoStatus
    public var errorMessage: String?
    @Relationship(deleteRule: .cascade, inverse: \MemoTransformation.memo)
    public var transformations: [MemoTransformation]

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        duration: TimeInterval = 0,
        audioFileName: String,
        transcript: String? = nil,
        language: String? = nil,
        status: MemoStatus = .recording,
        errorMessage: String? = nil,
        transformations: [MemoTransformation] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.duration = duration
        self.audioFileName = audioFileName
        self.transcript = transcript
        self.language = language
        self.status = status
        self.errorMessage = errorMessage
        self.transformations = transformations
    }

    public var displayTitle: String {
        if let transcript, !transcript.isEmpty {
            return String(transcript.prefix(60))
        }
        return "New Memo"
    }

    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%dMin. %dSec.", minutes, seconds)
    }

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    public static var audioDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDir = docs.appendingPathComponent("audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        return audioDir
    }

    public var audioFileURL: URL {
        Self.audioDirectory.appendingPathComponent(audioFileName)
    }
}
