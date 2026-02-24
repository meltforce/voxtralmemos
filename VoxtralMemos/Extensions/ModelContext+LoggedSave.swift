import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.meltforce.voxtralmemos", category: "SwiftData")

extension ModelContext {
    func loggedSave(file: String = #file, line: Int = #line) {
        do {
            try save()
        } catch {
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            logger.error("ModelContext.save() failed at \(fileName):\(line): \(error.localizedDescription)")
        }
    }
}
