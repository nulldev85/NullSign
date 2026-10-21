//
//  Storage+Shared.swift
//  Feather
//
//  Created by samara on 17.04.2025.
//

import CoreData

// MARK: - Class extension: Apps (Shared)
extension Storage {
	func getUuidDirectory(for app: AppInfoPresentable) -> URL? {
		guard let uuid = app.uuid else { return nil }
		return app.isSigned
			? FileManager.default.signed(uuid)
			: FileManager.default.unsigned(uuid)
	}

	func getAppDirectory(for app: AppInfoPresentable) -> URL? {
		guard let url = getUuidDirectory(for: app) else { return nil }
		return FileManager.default.getPath(in: url, for: "app")
	}

	func deleteApp(for app: AppInfoPresentable) {
		deleteApps([app])
	}

	/// Deletes apps and their files. Must be called on the main queue.
	///
	/// The database rows go first and are saved immediately, so every list
	/// drops the row before its bundle disappears from disk; the files are
	/// then removed off the main thread. Apps that were already deleted (a
	/// double tap, a stale row, a sheet still holding one) are skipped.
	func deleteApps(_ apps: [AppInfoPresentable]) {
		var directories: [URL] = []

		for app in apps {
			if let object = app as? NSManagedObject {
				guard
					object.managedObjectContext === context,
					!object.isDeleted
				else {
					continue
				}
			}

			if let url = getUuidDirectory(for: app) {
				directories.append(url)
			}
			deleteSourceMetadata(for: app.uuid, save: false)

			if let object = app as? NSManagedObject {
				context.delete(object)
			}
		}

		// If the save was rolled back the rows are still listed, so their
		// files must stay too.
		if saveContextNow() {
			FileManager.default.removeItemsInBackground(directories)
		}
	}

	func getCertificate(from app: AppInfoPresentable) -> CertificatePair? {
		if let signed = app as? Signed {
			return signed.certificate
		}
		return nil
	}
}

// MARK: - Helpers
struct AnyApp: Identifiable {
	let base: AppInfoPresentable
	var archive: Bool = false
	/// Captured once: a deleted app's uuid reads back as nil, and an id that
	/// changes while a sheet is up makes SwiftUI tear the sheet down.
	let id: String

	init(base: AppInfoPresentable, archive: Bool = false) {
		self.base = base
		self.archive = archive
		self.id = base.uuid
			?? (base as? NSManagedObject)?.objectID.uriRepresentation().absoluteString
			?? UUID().uuidString
	}
}

protocol AppInfoPresentable {
	var name: String? { get }
	var version: String? { get }
	var identifier: String? { get }
	var date: Date? { get }
	var icon: String? { get }
	var uuid: String? { get }
	var source: URL? { get }
	var isSigned: Bool { get }

}

extension Signed: AppInfoPresentable {
	var isSigned: Bool { true }
}

extension Imported: AppInfoPresentable {
	var isSigned: Bool { false }
}
