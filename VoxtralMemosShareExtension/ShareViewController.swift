import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleIncomingAudio()
    }

    private func handleIncomingAudio() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            complete(error: "No input items.")
            return
        }

        let audioType = UTType.audio.identifier

        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                guard provider.hasItemConformingToTypeIdentifier(audioType) else { continue }
                let name = provider.suggestedName
                provider.loadFileRepresentation(forTypeIdentifier: audioType) { [weak self] url, error in
                    guard let self else { return }
                    if let error {
                        DispatchQueue.main.async { self.complete(error: error.localizedDescription) }
                        return
                    }
                    guard let url else {
                        DispatchQueue.main.async { self.complete(error: "No file URL.") }
                        return
                    }
                    let originalName = name ?? url.lastPathComponent
                    // Must copy file synchronously — temp URL is deleted when this callback returns
                    self.copyToAppGroupAndComplete(source: url, originalName: originalName)
                }
                return
            }
        }

        complete(error: "No audio file found.")
    }

    /// Runs on the callback thread — copies the temp file before the system deletes it,
    /// then dispatches UI work to main.
    nonisolated private func copyToAppGroupAndComplete(source: URL, originalName: String) {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.meltforce.voxtralmemos") else {
            DispatchQueue.main.async { self.complete(error: "App group unavailable.") }
            return
        }

        let pendingDir = groupURL.appendingPathComponent("pendingImports", isDirectory: true)
        try? FileManager.default.createDirectory(at: pendingDir, withIntermediateDirectories: true)

        let ext = source.pathExtension.isEmpty ? "m4a" : source.pathExtension
        let destFileName = "\(UUID().uuidString).\(ext)"
        let destURL = pendingDir.appendingPathComponent(destFileName)

        do {
            try FileManager.default.copyItem(at: source, to: destURL)
        } catch {
            DispatchQueue.main.async { self.complete(error: "Copy failed: \(error.localizedDescription)") }
            return
        }

        let manifest: [String: String] = [
            "fileName": destFileName,
            "originalName": originalName,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        let manifestURL = pendingDir.appendingPathComponent("\(destFileName).json")
        if let data = try? JSONSerialization.data(withJSONObject: manifest) {
            try? data.write(to: manifestURL)
        }

        DispatchQueue.main.async {
            self.openMainApp()
            self.complete(error: nil)
        }
    }

    private func openMainApp() {
        guard let url = URL(string: "voxtral-memos://import") else { return }
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let application = next as? UIApplication {
                application.open(url)
                return
            }
            responder = next
        }
        let selector = sel_registerName("openURL:")
        responder = self
        while let next = responder?.next {
            if next.responds(to: selector) {
                next.perform(selector, with: url)
                return
            }
            responder = next
        }
    }

    private func complete(error: String?) {
        if let error {
            let nsError = NSError(domain: "VoxtralMemosShare", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
            extensionContext?.cancelRequest(withError: nsError)
        } else {
            extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
