import CoreData
import Foundation

// The production deletion extension runs against an isolated Core Data store.
@objc(DeletionTestImported)
class Imported: NSManagedObject {
	@NSManaged var uuid: String?
	@NSManaged var name: String?
	var identifier: String? { nil }
	var version: String? { nil }
	var date: Date? { nil }
	var icon: String? { nil }
	var source: URL? { nil }
}
final class CertificatePair {}
final class Signed: NSManagedObject {
	var uuid: String? { nil }
	var name: String? { nil }
	var identifier: String? { nil }
	var version: String? { nil }
	var date: Date? { nil }
	var icon: String? { nil }
	var source: URL? { nil }
	var certificate: CertificatePair? { nil }
}

extension FileManager {
	func unsigned(_ id: String) -> URL { temporaryDirectory.appendingPathComponent(id) }
	func signed(_ id: String) -> URL { unsigned(id) }
	func getPath(in url: URL, for ext: String) -> URL? { nil }
	func removeItemsInBackground(_ urls: [URL]) { Storage.shared.removed.append(contentsOf: urls) }
}

final class Storage {
	static let shared = Storage()
	let container: NSPersistentContainer
	var context: NSManagedObjectContext { container.viewContext }
	var removed: [URL] = []
	init() {
		let entity = NSEntityDescription()
		entity.name = "Imported"
		entity.managedObjectClassName = NSStringFromClass(Imported.self)
		entity.properties = ["uuid", "name"].map { key in
			let attribute = NSAttributeDescription()
			attribute.name = key
			attribute.attributeType = .stringAttributeType
			attribute.isOptional = false
			return attribute
		}
		let model = NSManagedObjectModel()
		model.entities = [entity]
		container = NSPersistentContainer(name: "DeletionTests", managedObjectModel: model)
		_ = try! container.persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType,
			configurationName: nil, at: nil, options: nil)
	}
	func saveContextNow() -> Bool {
		do { try context.save(); return true }
		catch { context.rollback(); return false }
	}
	func deleteSourceMetadata(for uuid: String?, save: Bool) {}
}

@main
enum LibraryDeletionTests {
	static func main() throws {
		let storage = Storage.shared
		let context = storage.context
		let first = Imported(context: context), second = Imported(context: context)
		first.uuid = "first"
		first.name = "Same App"
		second.uuid = "second"
		second.name = "Same App"
		try context.save()
		let request = NSFetchRequest<Imported>(entityName: "Imported")

		// A validation error elsewhere rolls back the delete and retains its files.
		let invalid = Imported(context: context)
		invalid.uuid = "invalid"
		precondition(!storage.deleteApps([first]))
		let afterRollback = try context.count(for: request)
		precondition(afterRollback == 2 && storage.removed.isEmpty)

		precondition(storage.deleteApps([first]))
		precondition(storage.deleteApps([first]))
		let remaining = try context.fetch(request)
		precondition(remaining.map(\.uuid) == ["second"])
		precondition(storage.removed.map(\.lastPathComponent) == ["first"])
		// Both contexts use the main queue so exercising a foreign row respects queue confinement.
		let other = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
		other.persistentStoreCoordinator = storage.container.persistentStoreCoordinator
		let otherCopy = try other.existingObject(with: second.objectID) as! Imported
		precondition(storage.deleteApps([otherCopy]))
		let afterDelete = try context.count(for: request)
		precondition(afterDelete == 0 && storage.removed.map(\.lastPathComponent) == ["first", "second"])
		print("Library deletion passed for same-name imports, retries, rollback and a second context.")
	}
}
