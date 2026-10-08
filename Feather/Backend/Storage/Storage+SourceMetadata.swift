//
//  Storage+SourceMetadata.swift
//  Feather
//
//  Created by Dominic on 26.05.2026.
//

import AltSourceKit
import CoreData
import Foundation

struct SourceAppProvenance: Equatable {
	let sourceRepositoryURL: URL
	let sourceRepositoryIdentifier: String?
	let sourceRepositoryName: String?
	let sourceAppIdentifier: String
	let sourceAppName: String?
	let sourceAppVersion: String?
	let sourceAppVersionDate: Date?
	let sourceAppDownloadURL: URL?
	
	var sourceVersionID: String {
		[
			sourceRepositoryIdentifier ?? sourceRepositoryURL.absoluteString,
			sourceAppIdentifier,
			sourceAppVersion ?? "",
			sourceAppDownloadURL?.absoluteString ?? ""
		].joined(separator: "|")
	}
}

enum SourceLinkedAppKind: String {
	case imported
	case signed
}

extension SourceAppProvenance {
	init?(
		sourceURL: URL?,
		repository: ASRepository,
		app: ASRepository.App,
		version: ASRepository.App.Version? = nil
	) {
		guard
			let sourceURL,
			let appIdentifier = app.id
		else {
			return nil
		}
		
		self.sourceRepositoryURL = sourceURL
		self.sourceRepositoryIdentifier = repository.id
		self.sourceRepositoryName = repository.name
		self.sourceAppIdentifier = appIdentifier
		self.sourceAppName = app.currentName
		let appVersion = version?.version ?? app.currentVersion
		let appVersionDate = version?.date?.date ?? app.currentDate?.date
		let appDownloadURL = version?.downloadURL ?? app.currentDownloadUrl
		self.sourceAppVersion = appVersion
		self.sourceAppVersionDate = appVersionDate
		self.sourceAppDownloadURL = appDownloadURL
	}
}

extension Storage {
	func sourceMetadata(for appUUID: String) -> AppSourceMetadata? {
		let request: NSFetchRequest<AppSourceMetadata> = AppSourceMetadata.fetchRequest()
		request.fetchLimit = 1
		request.predicate = NSPredicate(format: "appUUID == %@", appUUID)
		request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
		
		do {
			return try context.fetch(request).first
		} catch {
			return nil
		}
	}
	
	func sourceMetadata(for app: AppInfoPresentable) -> AppSourceMetadata? {
		guard let uuid = app.uuid else { return nil }
		return sourceMetadata(for: uuid)
	}
	
	func getSourceMetadata() -> [AppSourceMetadata] {
		let request: NSFetchRequest<AppSourceMetadata> = AppSourceMetadata.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: true)]
		do {
			return try context.fetch(request)
		} catch {
			return []
		}
	}
	
	/// Called from background import tasks, so the work is moved onto the
	/// main context's own queue.
	func addSourceMetadata(
		for appUUID: String,
		kind: SourceLinkedAppKind,
		provenance: SourceAppProvenance
	) {
		context.perform {
			let metadata = self.sourceMetadata(for: appUUID) ?? AppSourceMetadata(context: self.context)
			let now = Date()

			if metadata.createdAt == nil {
				metadata.createdAt = now
			}

			metadata.appUUID = appUUID
			metadata.appKind = kind.rawValue
			metadata.sourceRepositoryURL = provenance.sourceRepositoryURL
			metadata.sourceRepositoryIdentifier = provenance.sourceRepositoryIdentifier
			metadata.sourceRepositoryName = provenance.sourceRepositoryName
			metadata.sourceAppIdentifier = provenance.sourceAppIdentifier
			metadata.sourceAppName = provenance.sourceAppName
			metadata.sourceAppVersion = provenance.sourceAppVersion
			metadata.sourceAppVersionDate = provenance.sourceAppVersionDate
			metadata.sourceAppDownloadURL = provenance.sourceAppDownloadURL
			metadata.sourceVersionID = provenance.sourceVersionID
			metadata.updatedAt = now

			self.saveContextNow()
		}
	}
	
	func copySourceMetadata(
		from sourceAppUUID: String?,
		to destinationAppUUID: String,
		kind: SourceLinkedAppKind,
		completion: ((Error?) -> Void)? = nil
	) {
		guard
			let sourceAppUUID
		else {
			completion?(nil)
			return
		}

		// Signing finishes off the main thread, and the signing flow awaits
		// this via its completion handler (it must not report success, or
		// let the original app be deleted, off the back of a metadata copy
		// that silently failed). It still uses its own background context
		// rather than the main-queue viewContext, to avoid a forced
		// main-thread save right before the signing sheet dismisses.
		container.performBackgroundTask { backgroundContext in
			let sourceRequest: NSFetchRequest<AppSourceMetadata> = AppSourceMetadata.fetchRequest()
			sourceRequest.fetchLimit = 1
			sourceRequest.predicate = NSPredicate(format: "appUUID == %@", sourceAppUUID)
			sourceRequest.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

			guard
				let source = try? backgroundContext.fetch(sourceRequest).first,
				let repositoryURL = source.sourceRepositoryURL,
				let appIdentifier = source.sourceAppIdentifier,
				let versionID = source.sourceVersionID
			else {
				// Nothing to copy (app wasn't linked to a source) — not a failure.
				DispatchQueue.main.async {
					completion?(nil)
				}
				return
			}

			let destinationRequest: NSFetchRequest<AppSourceMetadata> = AppSourceMetadata.fetchRequest()
			destinationRequest.fetchLimit = 1
			destinationRequest.predicate = NSPredicate(format: "appUUID == %@", destinationAppUUID)

			let metadata = (try? backgroundContext.fetch(destinationRequest).first) ?? AppSourceMetadata(context: backgroundContext)
			let now = Date()
			if metadata.createdAt == nil {
				metadata.createdAt = now
			}
			metadata.appUUID = destinationAppUUID
			metadata.appKind = kind.rawValue
			metadata.sourceRepositoryURL = repositoryURL
			metadata.sourceRepositoryIdentifier = source.sourceRepositoryIdentifier
			metadata.sourceRepositoryName = source.sourceRepositoryName
			metadata.sourceAppIdentifier = appIdentifier
			metadata.sourceAppName = source.sourceAppName
			metadata.sourceAppVersion = source.sourceAppVersion
			metadata.sourceAppVersionDate = source.sourceAppVersionDate
			metadata.sourceAppDownloadURL = source.sourceAppDownloadURL
			metadata.sourceVersionID = versionID
			metadata.updatedAt = now

			do {
				try backgroundContext.save()
				DispatchQueue.main.async {
					completion?(nil)
				}
			} catch {
				DispatchQueue.main.async {
					completion?(error)
				}
			}
		}
	}
	
	/// Must be called on the main queue.
	func deleteSourceMetadata(for appUUID: String?, save: Bool = true) {
		guard let appUUID else {
			return
		}

		let request: NSFetchRequest<AppSourceMetadata> = AppSourceMetadata.fetchRequest()
		request.predicate = NSPredicate(format: "appUUID == %@", appUUID)
		request.includesPropertyValues = false

		guard let metadata = try? context.fetch(request), !metadata.isEmpty else {
			return
		}

		metadata.forEach(context.delete)
		if save {
			saveContextNow()
		}
	}

	/// Must be called on the main queue.
	func deleteSourceMetadata(kind: SourceLinkedAppKind) {
		let request: NSFetchRequest<AppSourceMetadata> = AppSourceMetadata.fetchRequest()
		request.predicate = NSPredicate(format: "appKind == %@", kind.rawValue)
		clearContext(request: request)
	}
}
