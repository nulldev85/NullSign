import Foundation
import SwiftUI

enum AppPlatform: String {
	case iOS
	case tvOS
}

// A signed/imported app's uuid names an immutable, per-app directory (a
// re-sign or re-import always gets a fresh uuid), so its Info.plist never
// changes underneath an existing uuid — safe to cache indefinitely.
private final class AppPlatformCache {
	static let shared = AppPlatformCache()
	private init() {}

	private let cache = NSCache<NSString, NSString>()

	func platform(for uuid: String) -> AppPlatform? {
		(cache.object(forKey: uuid as NSString) as String?).flatMap(AppPlatform.init(rawValue:))
	}

	func insert(_ platform: AppPlatform, for uuid: String) {
		cache.setObject(platform.rawValue as NSString, forKey: uuid as NSString)
	}
}

extension AppInfoPresentable {
	var platform: AppPlatform {
		if let uuid, let cached = AppPlatformCache.shared.platform(for: uuid) {
			return cached
		}

		guard let appURL = Storage.shared.getAppDirectory(for: self),
		      let info = NSDictionary(contentsOf: appURL.appendingPathComponent("Info.plist")) else {
			return .iOS
		}

		let supported = info["CFBundleSupportedPlatforms"] as? [String] ?? []
		let families = info["UIDeviceFamily"] as? [Int] ?? []
		let resolved: AppPlatform
		if supported.contains(where: { $0.localizedCaseInsensitiveContains("AppleTV") }) {
			resolved = .tvOS
		} else if supported.contains(where: { $0.localizedCaseInsensitiveContains("iPhone") }) {
			resolved = .iOS
		} else {
			resolved = supported.isEmpty && families.contains(3) ? .tvOS : .iOS
		}

		if let uuid {
			AppPlatformCache.shared.insert(resolved, for: uuid)
		}

		return resolved
	}
}

struct PlatformBadge: View {
	let platform: AppPlatform

	var body: some View {
		NullSignChip(
			text: platform.rawValue,
			systemImage: platform == .tvOS ? "appletv.fill" : "iphone",
			tint: platform == .tvOS ? NullSignStyle.crimson : Color.white,
			filled: platform == .tvOS,
			uppercased: false
		)
		.accessibilityLabel(platform == .tvOS ? "Apple TV app" : "iPhone app")
	}
}
