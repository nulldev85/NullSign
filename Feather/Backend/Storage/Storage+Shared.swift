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
		guard let uuid = app.uuid, !uuid.isEmpty, uuid != ".", uuid != "..",
			!uuid.contains("/") else { return nil }
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
	@discardableResult
	func deleteApps(_ apps: [AppInfoPresentable]) -> Bool {
		var directories: [URL] = []

		// Resolve the full selection before changing anything. Signed copies
		// can originate in a background context.
		var rows: [NSManagedObject] = []
		for app in apps {
			guard let object = app as? NSManagedObject else { return false }
			if object.managedObjectContext == nil { continue }
			if object.managedObjectContext === context {
				rows.append(object)
			} else {
				guard !object.objectID.isTemporaryID,
					let store = object.objectID.persistentStore,
					container.persistentStoreCoordinator.persistentStores.contains(where: { $0 === store }),
					let row = try? context.existingObject(with: object.objectID) else { return false }
				rows.append(row)
			}
		}
		for row in rows where !row.isDeleted {
			guard let app = row as? AppInfoPresentable else { continue }
			if let url = getUuidDirectory(for: app) {
				directories.append(url)
			}
			deleteSourceMetadata(for: app.uuid, save: false)

			context.delete(row)
		}

		// If the save was rolled back the rows are still listed, so their
		// files must stay too.
		guard saveContextNow() else { return false }
		FileManager.default.removeItemsInBackground(directories)
		return true
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

extension AppInfoPresentable {
	/// The build in the app's own Info.plist.
	var bundleBuild: String? { AppBuildNumbers.shared.build(of: self) }

	/// The version with the build from the app's own Info.plist, "0.19.0 (956)",
	/// so two builds of the same version can be told apart.
	var versionLabel: String? {
		guard let version, !version.isEmpty else { return version }
		guard let build = bundleBuild, !build.isEmpty, build != version else {
			return version
		}
		return "\(version) (\(build))"
	}
}

/// Build numbers read from each app's bundle on disk. A bundle never changes
/// once it is in the library, so each app is read once.
private final class AppBuildNumbers {
	static let shared = AppBuildNumbers()
	private let cache = NSCache<NSString, NSString>()

	func build(of app: AppInfoPresentable) -> String? {
		guard let uuid = app.uuid else { return nil }
		if let known = cache.object(forKey: uuid as NSString) { return known as String }
		// Nothing is remembered until the bundle is there to read.
		guard
			let directory = Storage.shared.getAppDirectory(for: app),
			let info = NSDictionary(contentsOf: directory.appendingPathComponent("Info.plist")),
			let build = info["CFBundleVersion"] as? String
		else { return nil }
		cache.setObject(build as NSString, forKey: uuid as NSString)
		return build
	}
}
