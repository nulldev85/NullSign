import Foundation


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
