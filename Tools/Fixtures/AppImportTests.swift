import Foundation
import Zip

struct SourceAppProvenance { let sourceRepositoryURL: URL }
enum SourceLinkedAppKind { case imported }
final class Download: @unchecked Sendable {
    let id = UUID().uuidString
    var sourceProvenance: SourceAppProvenance?
    var progressUpdates = 0
    var unpackageProgress: Double = 0 { didSet { progressUpdates += 1 } }
    var overallProgress: Double { unpackageProgress }
}
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    func updateProgress(for id: String, progress: Double) { }
}
final class Storage {
    static let shared = Storage()
    private let lock = NSLock()
    private var identifiers: [String] = []
    var savedIdentifiers: [String] { lock.withLock { identifiers } }

    func addImported(uuid: String, source: URL?, appName: String?, appIdentifier: String?,
                     appVersion: String?, appIcon: String?, completion: @escaping (Error?) -> Void) {
        // Completion deliberately arrives later, as it does with context.perform.
        DispatchQueue.main.async {
            if appIdentifier == "com.nullsign.fixture.reject" {
                completion(NSError(domain: "fixture.save", code: 1))
                return
            }
            self.lock.withLock { self.identifiers.append(appIdentifier ?? "missing") }
            completion(nil)
        }
    }
    func addSourceMetadata(for id: String, kind: SourceLinkedAppKind, provenance: SourceAppProvenance) { }
}

extension FileManager {
    func unsigned(_ id: String) -> URL {
        URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("Unsigned").appendingPathComponent(id)
    }
}
#if os(Linux)
extension URL {
    // Linux has no Files security scopes; iOS uses the platform implementation.
    static var documentsDirectory: URL { URL(fileURLWithPath: CommandLine.arguments[1]) }
    func startAccessingSecurityScopedResource() -> Bool { false }
    func stopAccessingSecurityScopedResource() { }
}
#endif

@main
struct AppImportTests {
    static func main() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let inputs = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Inputs"), includingPropertiesForKeys: nil)
        precondition(!Zip.isValidFileExtension("ipa") && !Zip.isValidFileExtension("tipa"))
        let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for folder in inputs {
                group.addTask {
                    let input = try! FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).first!
                    let download = Download()
                    let handler = AppFileHandler(file: input, download: download)
                    var stage = "copy"
                    do {
                        try await handler.copy()
                        stage = "extract"
                        try await handler.extract()
                        stage = "move"
                        try await handler.move()
                        stage = "save"
                        try await handler.addToDatabase()
                        try await handler.clean()
                        precondition(download.progressUpdates > 0 && download.progressUpdates <= 101,
                                     "Extraction flooded the UI with progress callbacks")
                        precondition(download.unpackageProgress == 1)
                        return true
                    } catch {
                        FileHandle.standardError.write(Data("Fixture \(folder.lastPathComponent) failed during \(stage): \(error)\n".utf8))
                        try! await handler.clean()
                        return false
                    }
                }
            }
            var results: [Bool] = []
            for await result in group { results.append(result) }
            return results
        }
        precondition(results.filter { $0 }.count == 33, "Lost an app during simultaneous imports: \(results.filter { $0 }.count) saved")
        precondition(results.filter { !$0 }.count == 3, "Corrupt archive, missing app, or failed save was accepted")
        let saved = Storage.shared.savedIdentifiers
        precondition(saved.count == 33 && Set(saved).count == 33, "Import completed before its database callback")
        let stored = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Unsigned"), includingPropertiesForKeys: nil)
        precondition(stored.count == 33, "Failed imports left partial library directories")
        precondition(!Zip.isValidFileExtension("ipa") && !Zip.isValidFileExtension("tipa"), "Importer mutated shared ZIP extensions")
        print("Batch import passed: 33 concurrent valid IPAs/TIPAs, 3 isolated failures, unique identities, bounded progress, and cleanup.")
    }
}
