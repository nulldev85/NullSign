//
//  Storage+Sources.swift
//  RyukSign
//
//  Created by samara on 12.04.2025.
//

import CoreData
import AltSourceKit
import OSLog
import UIKit.UIImpactFeedbackGenerator

// MARK: - Class extension: Sources
extension Storage {
	/// Retrieve sources in an array, we don't normally need this in swiftUI but we have it for the copy sources action
	func getSources() -> [AltSource] {
		let request: NSFetchRequest<AltSource> = AltSource.fetchRequest()
		return (try? context.fetch(request)) ?? []
	}
	
	func addSource(
		_ url: URL,
		name: String? = "Unknown",
		identifier: String,
		iconURL: URL? = nil,
		deferSave: Bool = false,
		completion: @escaping (Error?) -> Void
	) {
		if sourceExists(identifier) {
			completion(nil)
			Logger.misc.debug("ignoring \(identifier)")
			return
		}
		
		let generator = UIImpactFeedbackGenerator(style: .light)
		
		let new = AltSource(context: context)
		new.name = name
		new.date = Date()
		new.identifier = identifier
		new.sourceURL = url
		new.iconURL = iconURL
		
		do {
			if !deferSave {
				try context.save()
				generator.impactOccurred()
			}
			completion(nil)
		} catch {
			completion(error)
		}
	}
	
	func addSource(
		_ url: URL,
		repository: ASRepository,
		id: String = "",
		deferSave: Bool = false,
		completion: @escaping (Error?) -> Void
	) {
		addSource(
			url,
			name: repository.name,
			identifier: !id.isEmpty
						? id
						: (repository.id ?? url.absoluteString),
			iconURL: repository.currentIconURL,
			deferSave: deferSave,
			completion: completion
		)
	}

	func addSources(
		repos: [URL: ASRepository],
		completion: @escaping (Error?) -> Void
	) {
		let generator = UIImpactFeedbackGenerator(style: .light)
		
		for (url, repo) in repos {
			addSource(
				url,
				repository: repo,
				deferSave: true,
				completion: { error in
					if let error {
						completion(error)
					}
				}
			)
		}
		
		saveContext()
		generator.impactOccurred()
		completion(nil)
	}

	func deleteSource(for source: AltSource) {
		context.delete(source)
		saveContext()
	}

	func sourceExists(_ identifier: String) -> Bool {
		let fetchRequest: NSFetchRequest<AltSource> = AltSource.fetchRequest()
		fetchRequest.predicate = NSPredicate(format: "identifier == %@", identifier)

		do {
			let count = try context.count(for: fetchRequest)
			return count > 0
		} catch {
			Logger.misc.error("Error checking if repository exists: \(error)")
			return false
		}
	}
}

// MARK: - NullSign's own source
extension Storage {
	/// Null's Apps: NullSign itself, Lineup and Lineup tvOS.
	static let nullSignSourceURL = URL(string: "https://raw.githubusercontent.com/nulldev85/AppSource/main/apps.json")!

	/// NullSign comes with its own source, added once on first launch. If it's
	/// already there (NullSign 1.x saved it under its URL, lowercased) nothing
	/// is added, and once someone removes it, it isn't added again.
	func addNullSignSourceIfNeeded() {
		let key = "nullsign.didAddDefaultSource"
		guard !UserDefaults.standard.bool(forKey: key) else { return }
		UserDefaults.standard.set(true, forKey: key)

		let url = Self.nullSignSourceURL
		let target = url.absoluteString.lowercased()
		let alreadyAdded = getSources().contains { source in
			let identifier = source.identifier?.lowercased()
			let sourceURL = source.sourceURL?.absoluteString.lowercased()
				.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
			return identifier == target || sourceURL == target
		}
		guard !alreadyAdded else { return }

		addSource(
			url,
			name: "Null’s Apps",
			identifier: url.absoluteString,
			iconURL: URL(string: "https://raw.githubusercontent.com/nulldev85/AppSource/main/icons/source.png")
		) { error in
			if let error {
				Logger.misc.error("Couldn't add NullSign's source: \(error.localizedDescription)")
			}
		}
	}
}
