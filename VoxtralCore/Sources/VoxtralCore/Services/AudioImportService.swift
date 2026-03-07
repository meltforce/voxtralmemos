import Foundation
import AVFoundation

public enum AudioImportError: LocalizedError {
    case unsupportedFormat(String)
    case durationExceedsLimit(TimeInterval, max: TimeInterval)
    case conversionFailed(String)
    case fileNotReadable

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "Unsupported audio format: .\(ext)"
        case .durationExceedsLimit(let duration, let max):
            let mins = Int(duration / 60)
            let maxMins = Int(max / 60)
            return "Audio is \(mins) minutes long. Maximum is \(maxMins) minutes."
        case .conversionFailed(let reason):
            return "Audio conversion failed: \(reason)"
        case .fileNotReadable:
            return "Cannot read the audio file."
        }
    }
}

public struct AudioImportResult: Sendable {
    public let duration: TimeInterval
    public let mimeType: String
    public let fileName: String
    public let didConvert: Bool
}

public enum AudioImportService {
    private static let nativeFormats: Set<String> = ["mp3", "wav", "m4a", "flac", "ogg"]

    private static let mimeTypes: [String: String] = [
        "mp3": "audio/mpeg",
        "wav": "audio/wav",
        "m4a": "audio/mp4",
        "flac": "audio/flac",
        "ogg": "audio/ogg",
    ]

    public static func mimeType(for fileExtension: String) -> String {
        mimeTypes[fileExtension.lowercased()] ?? "audio/mp4"
    }

    public static func audioDuration(of url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return duration.seconds
    }

    public static func convertToM4A(source: URL, destination: URL) async throws {
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioImportError.conversionFailed("Cannot create export session.")
        }
        try await session.export(to: destination, as: .m4a)
    }

    public static let defaultMaxDuration: TimeInterval = 60 * 60 // 60 minutes

    /// Coordinates reading a file that may be stored in iCloud, downloading it if needed.
    /// Returns a local file URL that is guaranteed to be readable.
    private static func coordinatedURL(for url: URL) throws -> URL {
        // If the file is already local and readable, skip coordination
        if FileManager.default.isReadableFile(atPath: url.path) {
            return url
        }

        // Trigger iCloud download if the file is evicted
        if FileManager.default.isUbiquitousItem(at: url) {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        }

        // Use NSFileCoordinator to wait for the download and get access
        var coordinatedURL = url
        var coordinationError: NSError?
        var copyError: Error?
        let coordinator = NSFileCoordinator()
        let tempDir = FileManager.default.temporaryDirectory
        let localCopy = tempDir.appendingPathComponent(url.lastPathComponent)

        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { accessedURL in
            do {
                if FileManager.default.fileExists(atPath: localCopy.path) {
                    try FileManager.default.removeItem(at: localCopy)
                }
                try FileManager.default.copyItem(at: accessedURL, to: localCopy)
                coordinatedURL = localCopy
            } catch {
                copyError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        if let copyError {
            throw copyError
        }

        guard FileManager.default.isReadableFile(atPath: coordinatedURL.path) else {
            throw AudioImportError.fileNotReadable
        }
        return coordinatedURL
    }

    public static func validateAndPrepare(
        url: URL,
        maxDuration: TimeInterval = defaultMaxDuration,
        targetDirectory: URL
    ) async throws -> AudioImportResult {
        let localURL = try coordinatedURL(for: url)

        let ext = localURL.pathExtension.lowercased()
        let isNative = nativeFormats.contains(ext)

        // Check if we can handle this format at all
        if !isNative {
            // Try to open with AVURLAsset to see if it's convertible
            let asset = AVURLAsset(url: localURL)
            let tracks = try await asset.load(.tracks)
            guard !tracks.isEmpty else {
                throw AudioImportError.unsupportedFormat(ext)
            }
        }

        let duration = try await audioDuration(of: localURL)
        guard duration <= maxDuration else {
            throw AudioImportError.durationExceedsLimit(duration, max: maxDuration)
        }

        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        let outputFileName: String
        let didConvert: Bool
        let resolvedMime: String

        if isNative {
            outputFileName = "\(UUID().uuidString).\(ext)"
            let destination = targetDirectory.appendingPathComponent(outputFileName)
            try FileManager.default.copyItem(at: localURL, to: destination)
            didConvert = false
            resolvedMime = mimeType(for: ext)
        } else {
            outputFileName = "\(UUID().uuidString).m4a"
            let destination = targetDirectory.appendingPathComponent(outputFileName)
            try await convertToM4A(source: localURL, destination: destination)
            didConvert = true
            resolvedMime = "audio/mp4"
        }

        return AudioImportResult(
            duration: duration,
            mimeType: resolvedMime,
            fileName: outputFileName,
            didConvert: didConvert
        )
    }
}
