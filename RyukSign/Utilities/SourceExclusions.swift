//
//  SourceExclusions.swift
//  RyukSign
//
//  Created by Ryuk
//

import Foundation

/// Sources hidden from All Apps. They stay saved and can still be opened on
/// their own.
enum SourceExclusions {
	private static let _key = "RyukSign.excludedSourceIdentifiers"

	/// Identifiers of the sources hidden from All Apps.
	static var identifiers: Set<String> {
		get { Set(UserDefaults.standard.stringArray(forKey: _key) ?? []) }
		set { UserDefaults.standard.set(Array(newValue), forKey: _key) }
	}

	static func isExcluded(_ identifier: String) -> Bool {
		identifiers.contains(identifier)
	}

	static func setExcluded(_ identifier: String, excluded: Bool) {
		var ids = identifiers
		if excluded {
			ids.insert(identifier)
		} else {
			ids.remove(identifier)
		}
		identifiers = ids
	}
}
