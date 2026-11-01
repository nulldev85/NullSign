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
    struct Record {
        let identifier: String
        let name: String?
        let version: String?
        let icon: String?
    }
    static let shared = Storage()
    private let lock = NSLock()
    private var records: [Record] = []
    var savedRecords: [Record] { lock.withLock { records } }

    func addImported(uuid: String, source: URL?, appName: String?, appIdentifier: String?,
                     appVersion: String?, appIcon: String?, completion: @escaping (Error?) -> Void) {
        // Completion deliberately arrives later, as it does with context.perform.
        DispatchQueue.main.async {
            guard let appIdentifier, !appIdentifier.isEmpty else {
                completion(NSError(domain: "fixture.missingMetadata", code: 1))
                return
            }
            if appIdentifier == "com.nullsign.fixture.reject" {
                completion(NSError(domain: "fixture.save", code: 1))
                return
            }
            self.lock.withLock {
                self.records.append(Record(identifier: appIdentifier, name: appName, version: appVersion, icon: appIcon))
            }
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
        let results = await withTaskGroup(of: (String, Bool).self, returning: [String: Bool].self) { group in
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
                        return (folder.lastPathComponent, true)
                    } catch {
                        FileHandle.standardError.write(Data("Fixture \(folder.lastPathComponent) failed during \(stage): \(error)\n".utf8))
                        try! await handler.clean()
                        return (folder.lastPathComponent, false)
                    }
                }
            }
            var results: [String: Bool] = [:]
            for await (fixture, succeeded) in group { results[fixture] = succeeded }
            return results
        }
        precondition(results.values.filter { $0 }.count == 33, "Lost an app during simultaneous imports: \(results.values.filter { $0 }.count) saved")
        precondition(Set(results.filter { !$0.value }.keys) == ["33", "34", "35", "36"],
                     "Corrupt archive, missing app, failed save, or invalid metadata was accepted")
        let saved = Storage.shared.savedRecords
        precondition(saved.count == 33 && Set(saved.map(\.identifier)) == Set((0..<33).map { "com.nullsign.fixture.\($0)" }),
                     "Import completed before its database callback or lost an app's identifier")
        for record in saved {
            let index = Int(record.identifier.split(separator: ".").last!)!
            let expectedName = index % 3 == 0 ? "Displayed \(index)" : (index % 3 == 1 ? "Fixture \(index)" : "Fixture")
            precondition(record.name == expectedName, "Lost the imported app's display name")
            precondition(record.version == (index % 2 == 0 ? "1.0" : "1"), "Lost the imported app's version")
            precondition(record.icon == "Icon\(index)", "Lost the imported app's icon filename")
        }
        let stored = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Unsigned"), includingPropertiesForKeys: nil)
        precondition(stored.count == 33, "Failed imports left partial library directories")
        precondition(!Zip.isValidFileExtension("ipa") && !Zip.isValidFileExtension("tipa"), "Importer mutated shared ZIP extensions")
        print("Batch import passed: 33 concurrent valid IPAs/TIPAs, 4 isolated failures, exact XML/binary metadata, bounded progress, and cleanup.")
    }
}
