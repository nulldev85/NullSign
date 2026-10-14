import Foundation

/// Resolve the icon declared by this package, not artwork associated with its
/// bundle identifier or an unrelated/alternate icon left in the catalog.
enum TVIconSelection {
	static func isTVApp(_ info: [String: Any]) -> Bool {
		let families = info["UIDeviceFamily"] as? [Int] ?? []
		let platforms = info["CFBundleSupportedPlatforms"] as? [String] ?? []
		return families.contains(3) || platforms.contains { $0.localizedCaseInsensitiveContains("appletv") }
	}

	static func assetNames(in info: [String: Any]) -> [String] {
		var names: [String] = []
		if let icons = info["CFBundleIcons"] as? [String: Any] {
			if let primary = icons["CFBundlePrimaryIcon"] as? String {
				names.append(primary)
			} else if let primary = icons["CFBundlePrimaryIcon"] as? [String: Any] {
				if let name = primary["CFBundleIconName"] as? String { names.append(name) }
				if let files = primary["CFBundleIconFiles"] as? [String] { names.append(contentsOf: files.reversed()) }
			}
		}
		// Legacy packages can declare their icon at the plist root.
		names.removeAll { $0.isEmpty }
		if names.isEmpty {
			if let name = info["CFBundleIconName"] as? String { names.append(name) }
			if let files = info["CFBundleIconFiles"] as? [String] { names.append(contentsOf: files.reversed()) }
			if let file = info["CFBundleIconFile"] as? String { names.append(file) }
		}
		var seen = Set<String>()
		let declared = names.filter { !$0.isEmpty && seen.insert($0).inserted }
		// Guess names only when the package declares no primary icon. Never
		// replace an unreadable current icon with an older catalog's generic one.
		return declared.isEmpty ? ["App Icon - Small", "App Icon - Large", "App Icon", "AppIcon"] : declared
	}

	static func looseFileNames(for name: String) -> [String] {
		let base = name.lowercased().hasSuffix(".png") ? String(name.dropLast(4)) : name
		return ["\(base)@3x.png", "\(base)@2x.png", "\(base).png"]
	}
}
