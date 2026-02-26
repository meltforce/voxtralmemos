import Foundation

public struct NetworkConfiguration: Sendable {
    public let requestTimeout: TimeInterval
    public let resourceTimeout: TimeInterval
    public let maxRetries: Int
    public let baseRetryDelay: TimeInterval

    public init(
        requestTimeout: TimeInterval,
        resourceTimeout: TimeInterval,
        maxRetries: Int,
        baseRetryDelay: TimeInterval
    ) {
        self.requestTimeout = requestTimeout
        self.resourceTimeout = resourceTimeout
        self.maxRetries = maxRetries
        self.baseRetryDelay = baseRetryDelay
    }

    public static let `default` = NetworkConfiguration(
        requestTimeout: 30,
        resourceTimeout: 300,
        maxRetries: 3,
        baseRetryDelay: 1
    )

    public static let transcription = NetworkConfiguration(
        requestTimeout: 60,
        resourceTimeout: 600,
        maxRetries: 2,
        baseRetryDelay: 2
    )
}
