//
//  Storage+Sources.swift
//  Feather
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
		let normalizedURL = normalizedSourceURL(url)
		let normalizedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		if sourceExists(normalizedIdentifier) || sourceExists(url: normalizedURL) {
			completion(nil)
			Logger.misc.debug("Ignoring duplicate repository \(normalizedURL.absoluteString)")
			return
		}
		
		let generator = UIImpactFeedbackGenerator(style: .light)
		
		let new = AltSource(context: context)
		new.name = name
		new.date = Date()
		new.identifier = normalizedIdentifier
		new.sourceURL = normalizedURL
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
		var firstError: Error?
		
		for (url, repo) in repos {
			addSource(
				url,
				repository: repo,
				deferSave: true,
				completion: { error in
					if firstError == nil { firstError = error }
				}
			)
		}
		
		saveContext()
		generator.impactOccurred()
		completion(firstError)
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

	func sourceExists(url: URL) -> Bool {
		let normalized = normalizedSourceURL(url).absoluteString
		let request: NSFetchRequest<AltSource> = AltSource.fetchRequest()
		guard let sources = try? context.fetch(request) else { return false }
		return sources.contains { source in
			guard let existing = source.sourceURL else { return false }
			return normalizedSourceURL(existing).absoluteString == normalized
		}
	}

	private func normalizedSourceURL(_ url: URL) -> URL {
		guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
		components.scheme = components.scheme?.lowercased()
		components.host = components.host?.lowercased()
		components.fragment = nil
		if components.path.count > 1 && components.path.hasSuffix("/") {
			components.path.removeLast()
		}
		return components.url ?? url
	}
}
