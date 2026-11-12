import Foundation
import Zip

struct SourceAppProvenance { let sourceRepositoryURL: URL }
enum SourceLinkedAppKind { case imported }
final class Download: @unchecked Sendable {
    let id = UUID().uuidString
    var sourceProvenance: SourceAppProvenance?
    var importCompleted = false
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
		let copySource = root.appendingPathComponent("Coordinated-✓.ipa")
		let copyDestination = root.appendingPathComponent("Coordinated-copy.zip")
		let copyBytes = Data([0x50, 0x4b, 0, 255, 1, 2, 3])
		try copyBytes.write(to: copySource)
		try ArchiveFileAccess.copy(from: copySource, to: copyDestination)
		let copiedBytes = try Data(contentsOf: copyDestination)
		precondition(copiedBytes == copyBytes)
		do {
			try ArchiveFileAccess.copy(from: root.appendingPathComponent("missing.ipa"), to: root.appendingPathComponent("missing-copy.zip"))
			preconditionFailure("A failed coordinated file read must throw to the import UI")
		} catch {
			precondition(!error.localizedDescription.isEmpty)
		}
		print("PASS real coordinated file copy preserves bytes/Unicode paths and propagates unreadable-file errors")
        let inputs = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Inputs"), includingPropertiesForKeys: nil)
        precondition(!Zip.isValidFileExtension("ipa") && !Zip.isValidFileExtension("tipa"))
        let results = await withTaskGroup(of: (String, Bool).self, returning: [String: Bool].self) { group in
            for folder in inputs {
                group.addTask {
                    let input = try! FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).first!
                    let download = Download()
                    do {
                        try await AppImportOperation.run(file: input, download: download)
                        precondition(download.progressUpdates > 0 && download.progressUpdates <= 101,
                                     "Extraction flooded the UI with progress callbacks")
                        precondition(download.unpackageProgress == 1)
                        precondition(download.importCompleted, "Import completed before the saved-library result")
                        return (folder.lastPathComponent, true)
                    } catch {
                        FileHandle.standardError.write(Data("Fixture \(folder.lastPathComponent) failed: \(error.localizedDescription)\n".utf8))
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
		for (index, expectedStage) in [(33, AppImportFailure.Stage.unpacking), (34, .addingToLibrary), (35, .addingToLibrary), (36, .addingToLibrary)] {
			let folder = root.appendingPathComponent("Inputs/\(index)")
			let file = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).first!
			let original = try Data(contentsOf: file)
			do {
				try await AppImportOperation.run(file: file)
				preconditionFailure("Failed import was reported as success")
			} catch let error as AppImportFailure {
				precondition(error.stage == expectedStage && !error.localizedDescription.isEmpty)
			}
			let retained = try Data(contentsOf: file)
			precondition(retained == original, "Import failure changed the user's original IPA")
		}
		do {
			try await AppImportOperation.run(file: root.appendingPathComponent("missing.ipa"))
			preconditionFailure("Unreadable file was reported as success")
		} catch let error as AppImportFailure {
			precondition(error.stage == .reading)
		}
		print("PASS production import operation reports file-read/archive/metadata/database errors, preserves inputs and cleans failed imports")
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
