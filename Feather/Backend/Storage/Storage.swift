//
//  Persistence.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import CoreData
import Foundation
import OSLog

// MARK: - Storage
final class Storage: ObservableObject {
	static let shared = Storage()
	let container: NSPersistentContainer

	private let _name: String = "Feather"

	init(inMemory: Bool = false) {
		container = NSPersistentContainer(name: _name)

		if inMemory {
			container.persistentStoreDescriptions.first?.url =
				URL(fileURLWithPath: "/dev/null")
		}

		container.persistentStoreDescriptions.first?.shouldMigrateStoreAutomatically = true
		container.persistentStoreDescriptions.first?.shouldInferMappingModelAutomatically = true

		_loadPersistentStoreAggressively()
		container.viewContext.automaticallyMergesChangesFromParent = true
		container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
	}

	var context: NSManagedObjectContext {
		container.viewContext
	}

	/// Saves the main context on its own queue. Safe to call from any thread.
	func saveContext() {
		context.perform { [weak self] in
			self?.saveContextNow()
		}
	}

	/// Saves immediately. Must be called on the main queue.
	///
	/// A failed save is rolled back: a context holding an object that can
	/// never validate would otherwise make every later save fail too.
	func saveContextNow() {
		guard context.hasChanges else { return }
		do {
			try context.save()
		} catch {
			Logger.misc.error("Core Data save failed: \(error.localizedDescription)")
			context.rollback()
		}
	}

	/// Deletes every object of a type through the context, so delete rules
	/// are honored and on-screen fetch requests update immediately instead
	/// of holding faults for rows that no longer exist.
	/// Must be called on the main queue.
	func clearContext<T: NSManagedObject>(request: NSFetchRequest<T>) {
		request.includesPropertyValues = false
		guard let objects = try? context.fetch(request) else { return }
		objects.forEach(context.delete)
		saveContextNow()
	}

	func countContent<T: NSManagedObject>(for type: T.Type) -> String {
		let request = T.fetchRequest()
		return "\((try? context.count(for: request)) ?? 0)"
	}

	private func _loadPersistentStoreAggressively() {
		container.loadPersistentStores { description, error in
			guard error != nil else { return }

			self._destroyStore(at: description.url)
			self.container.loadPersistentStores { _, error in
				guard let error else { return }

				// Last resort: keep the app usable for this session rather than
				// crashing on every launch. Nothing is persisted in this mode.
				Logger.misc.critical("Core Data unrecoverable, using a temporary store: \(error.localizedDescription)")
				let memory = NSPersistentStoreDescription()
				memory.type = NSInMemoryStoreType
				self.container.persistentStoreDescriptions = [memory]
				self.container.loadPersistentStores { _, error in
					if let error {
						fatalError("Core Data unrecoverable: \(error)")
					}
				}
			}
		}
	}

	private func _destroyStore(at url: URL?) {
		guard let url else { return }

		let base = url.deletingPathExtension()
		let fm = FileManager.default

		let files = [
			base.appendingPathExtension("sqlite"),
			base.appendingPathExtension("sqlite-wal"),
			base.appendingPathExtension("sqlite-shm")
		]

		for file in files {
			try? fm.removeItem(at: file)
		}

		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.signed)
		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.unsigned)
		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.certificates)
		UserDefaults.standard.set(0, forKey: "feather.selectedCert")
		UserDefaults.standard.removeObject(forKey: "feather.selectedCert.iOS")
		UserDefaults.standard.removeObject(forKey: "feather.selectedCert.tvOS")
	}
}

// MARK: - Files
extension FileManager {
	/// Removes the given items on a background queue. Paths are resolved by
	/// the caller first, so items created afterwards are never touched.
	func removeItemsInBackground(_ urls: [URL]) {
		guard !urls.isEmpty else { return }
		DispatchQueue.global(qos: .utility).async {
			for url in urls {
				try? FileManager.default.removeItem(at: url)
			}
		}
	}

	/// Empties a directory without removing the directory itself, so later
	/// imports and signs can keep moving files into it.
	func removeContentsInBackground(of directory: URL) {
		let items = (try? contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
		removeItemsInBackground(items)
	}
}
