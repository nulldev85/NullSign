//
//  LibraryPruner.swift
//  Feather
//

import Foundation

/// Keeps only the newest copy of each app, when the user turns it on. Imported
/// and Signed are pruned apart, so an app can keep one of each. A copy goes
/// once a copy of the same app added after it is the same version or newer:
/// updating, or importing the same version again, replaces the old copy,
/// while an older version imported on purpose stays. The copy added last is
/// never removed, so a sign or update in progress keeps the row it just made.
enum LibraryPruner {
	static let settingKey = "NullSign.keepNewestVersionOnly"

	static var isEnabled: Bool {
		UserDefaults.standard.bool(forKey: settingKey)
	}

	/// The copies a later copy of the same app has replaced.
	static func replaced(in apps: [AppInfoPresentable]) -> [AppInfoPresentable] {
		let groups = Dictionary(grouping: apps.filter { app in
			app.uuid != nil && app.date != nil && !(app.identifier ?? "").isEmpty
		}) { app in
			"\(app.isSigned ? "signed" : "imported")|\(app.identifier ?? "")"
		}

		var replaced: [AppInfoPresentable] = []
		for copies in groups.values where copies.count > 1 {
			for copy in copies {
				let isReplaced = copies.contains { later in
					guard let laterDate = later.date, let date = copy.date, laterDate > date else {
						return false
					}
					return !ReleaseOrder.isNewer(
						copy.version ?? "", build: copy.bundleBuild,
						than: later.version ?? "", installedBuild: later.bundleBuild
					)
				}
				if isReplaced { replaced.append(copy) }
			}
		}
		return replaced
	}

	/// Deletes the replaced copies when the setting is on, and returns their uuids.
	@MainActor
	@discardableResult
	static func pruneIfEnabled(_ apps: [AppInfoPresentable]) -> Set<String> {
		guard isEnabled else { return [] }
		let old = replaced(in: apps)
		guard !old.isEmpty else { return [] }
		let uuids = Set(old.compactMap(\.uuid))
		Storage.shared.deleteApps(old)
		return uuids
	}
}
