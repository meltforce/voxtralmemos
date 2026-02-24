import Foundation
import SwiftData

public enum TransformationStatus: String, Codable {
    case pending, processing, ready, failed
}

@Model
public final class MemoTransformation {
    public var id: UUID
    public var createdAt: Date
    public var result: String?
    public var status: TransformationStatus
    public var errorMessage: String?
    public var modelUsed: String
    public var promptSnapshot: String?
    public var selectedAt: Date?
    public var memo: Memo?
    public var template: PromptTemplate?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        result: String? = nil,
        status: TransformationStatus = .pending,
        errorMessage: String? = nil,
        modelUsed: String = "",
        promptSnapshot: String? = nil,
        selectedAt: Date? = nil,
        memo: Memo? = nil,
        template: PromptTemplate? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.result = result
        self.status = status
        self.errorMessage = errorMessage
        self.modelUsed = modelUsed
        self.promptSnapshot = promptSnapshot
        self.selectedAt = selectedAt
        self.memo = memo
        self.template = template
    }
}
