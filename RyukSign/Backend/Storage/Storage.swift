//
//  Persistence.swift
//  RyukSign
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

		_loadPersistentStoreAggressively()
		container.viewContext.automaticallyMergesChangesFromParent = true
		container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
		_migrateSortIndexIfNeeded()
		_migrateOriginalIdentifierIfNeeded()
	}
	
	var context: NSManagedObjectContext {
		container.viewContext
	}
	
	func saveContext() {
		// Save sync if already on main to avoid a deadlock
		if Thread.isMainThread {
			if context.hasChanges {
				do {
					try context.save()
				} catch {
					Logger.misc.error("CoreData save failed: \(error.localizedDescription)")
				}
			}
		} else {
			DispatchQueue.main.async {
				if self.context.hasChanges {
					do {
						try self.context.save()
					} catch {
						Logger.misc.error("CoreData save failed: \(error.localizedDescription)")
					}
				}
			}
		}
	}
	
	func clearContext<T: NSManagedObject>(request: NSFetchRequest<T>) {
		let deleteRequest = NSBatchDeleteRequest(fetchRequest: (request as? NSFetchRequest<NSFetchRequestResult>)!)
		_ = try? context.execute(deleteRequest)
	}
	
	func countContent<T: NSManagedObject>(for type: T.Type) -> String {
		let request = T.fetchRequest()
		return "\((try? context.count(for: request)) ?? 0)"
	}

	private func _loadPersistentStoreAggressively() {
		container.loadPersistentStores { description, error in
			if let error {
				Logger.misc.error("CoreData store failed to load, setting it aside: \(error.localizedDescription)")
				self._setAsideStore(at: description.url)
				self.container.loadPersistentStores { _, error in
					if let error {
						fatalError("Core Data unrecoverable: \(error)")
					}
				}
			}
		}
	}

	// Libraries from NullSign 1.x have no originalIdentifier; the model gives
	// them an empty one so they migrate. Fill in the bundle identifier, which
	// is what an app imported or signed since then records.
	private func _migrateOriginalIdentifierIfNeeded() {
		let key = "nullsign.originalIdentifierMigrated"
		guard !UserDefaults.standard.bool(forKey: key) else { return }

		let empty = NSPredicate(format: "originalIdentifier == nil OR originalIdentifier == ''")
		let signedRequest: NSFetchRequest<Signed> = Signed.fetchRequest()
		signedRequest.predicate = empty
		for app in (try? context.fetch(signedRequest)) ?? [] {
			app.originalIdentifier = app.identifier
		}

		let importedRequest: NSFetchRequest<Imported> = Imported.fetchRequest()
		importedRequest.predicate = empty
		for app in (try? context.fetch(importedRequest)) ?? [] {
			app.originalIdentifier = app.identifier
		}

		saveContext()
		UserDefaults.standard.set(true, forKey: key)
	}

	// Backfills sortIndex from the old date-desc order so manual reordering starts stable
	private func _migrateSortIndexIfNeeded() {
		let key = "feather.sortIndexMigrated"
		guard !UserDefaults.standard.bool(forKey: key) else { return }

		let signedRequest: NSFetchRequest<Signed> = Signed.fetchRequest()
		signedRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Signed.date, ascending: false)]
		if let apps = try? context.fetch(signedRequest) {
			for (index, app) in apps.enumerated() { app.sortIndex = Int32(index) }
		}

		let importedRequest: NSFetchRequest<Imported> = Imported.fetchRequest()
		importedRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Imported.date, ascending: false)]
		if let apps = try? context.fetch(importedRequest) {
			for (index, app) in apps.enumerated() { app.sortIndex = Int32(index) }
		}

		saveContext()
		UserDefaults.standard.set(true, forKey: key)
	}

	/// A store that won't open is moved into a dated backup folder, never
	/// deleted, and the app starts with an empty one. Library and certificate
	/// files stay where they are, so nothing a person added is lost.
	private func _setAsideStore(at url: URL?) {
		guard let url else { return }

		let base = url.deletingPathExtension()
		let fm = FileManager.default
		let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
		let backup = URL.documentsDirectory
			.appendingPathComponent("Library Backups", isDirectory: true)
			.appendingPathComponent(stamp, isDirectory: true)
		try? fm.createDirectory(at: backup, withIntermediateDirectories: true)

		for ext in ["sqlite", "sqlite-wal", "sqlite-shm"] {
			let file = base.appendingPathExtension(ext)
			guard fm.fileExists(atPath: file.path) else { continue }
			try? fm.moveItem(at: file, to: backup.appendingPathComponent(file.lastPathComponent))
		}
	}
}
