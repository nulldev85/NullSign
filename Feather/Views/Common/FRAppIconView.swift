//
//  FRAppIconView.swift
//  Feather
//
//  Created by samara on 18.04.2025.
//

import SwiftUI

enum FRIconAppearance: Int {
	case light = 0
	case dark = 1
}

final class FRIconCache {
	static let shared = FRIconCache()
	private init() {}

	private let cache = NSCache<NSString, UIImage>()

	private func key(url: URL, appearance: FRIconAppearance, tint: String, isTinted: Bool, dynamic: Bool) -> NSString {
		"\(url.path)#\(appearance.rawValue)#\(tint)#\(isTinted)#\(dynamic)" as NSString
	}

	func image(for url: URL, appearance: FRIconAppearance, tint: String, isTinted: Bool, dynamic: Bool) -> UIImage? {
		cache.object(forKey: key(url: url, appearance: appearance, tint: tint, isTinted: isTinted, dynamic: dynamic))
	}

	func insert(_ image: UIImage, for url: URL, appearance: FRIconAppearance, tint: String, isTinted: Bool, dynamic: Bool) {
		cache.setObject(image, forKey: key(url: url, appearance: appearance, tint: tint, isTinted: isTinted, dynamic: dynamic))
	}

	func invalidateAll() {
		cache.removeAllObjects()
	}
}

/// Renders icons one at a time. IconServices is private API with no
/// thread-safety guarantees, and a list appearing used to start one render
/// per row at once.
private actor FRIconRenderer {
	static let shared = FRIconRenderer()

	func render(bundleURL: URL) -> UIImage? {
		// The bundle can be deleted between a row appearing and this running;
		// never hand IconServices a bundle that is no longer on disk.
		guard FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("Info.plist").path) else {
			return nil
		}

		return tvOSIcon(in: bundleURL) ?? iconTest(bundleURL)
	}
}

@MainActor
final class FRAppIconLoader: ObservableObject {
	@Published var image: UIImage?
	private var task: Task<Void, Never>?
	private var representedRequest: String?

	func load(bundleURL: URL, appearance: FRIconAppearance, tint: String, isTinted: Bool, dynamic: Bool) {
		let request = "\(bundleURL.path)#\(appearance.rawValue)#\(tint)#\(isTinted)#\(dynamic)"
		task?.cancel()
		representedRequest = request

		if let cached = FRIconCache.shared.image(for: bundleURL, appearance: appearance, tint: tint, isTinted: isTinted, dynamic: dynamic) {
			self.image = cached
			return
		}

		image = nil
		task = Task {
			let generated = await FRIconRenderer.shared.render(bundleURL: bundleURL)

			guard !Task.isCancelled, representedRequest == request else { return }

			if let generated {
				FRIconCache.shared.insert(generated, for: bundleURL, appearance: appearance, tint: tint, isTinted: isTinted, dynamic: dynamic)
				self.image = generated
			}
		}
	}

	func cancel() {
		task?.cancel()
	}
}

/// tvOS app icons are layered brand assets rather than the single iOS icon
/// IconServices expects. Resolve both the tvOS string-style Info.plist entry
/// and the individual layers compiled into Assets.car, then fall back to loose
/// artwork for older packages.
private func tvOSIcon(in bundleURL: URL) -> UIImage? {
	guard let bundle = Bundle(url: bundleURL) else { return nil }
	let families = bundle.object(forInfoDictionaryKey: "UIDeviceFamily") as? [Int] ?? []
	let platforms = bundle.object(forInfoDictionaryKey: "CFBundleSupportedPlatforms") as? [String] ?? []
	guard families.contains(3) || platforms.contains(where: { $0.localizedCaseInsensitiveContains("appletv") }) else {
		return nil
	}

	var names: [String] = []
	if let icons = bundle.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any] {
		// tvOS writes the primary icon as a brand-asset name, unlike the nested
		// dictionary used by iOS.
		if let primaryName = icons["CFBundlePrimaryIcon"] as? String {
			names.append(primaryName)
		} else if let primary = icons["CFBundlePrimaryIcon"] as? [String: Any] {
			if let name = primary["CFBundleIconName"] as? String { names.append(name) }
			if let files = primary["CFBundleIconFiles"] as? [String] {
				names.append(contentsOf: files.reversed())
			}
		}
	}
	names.append(contentsOf: ["App Icon - Small", "App Icon - Large", "App Icon", "AppIcon"])
	let uniqueNames = _uniqueIconNames(names)

	// Read and flatten the tvOS layer stack directly from the imported app's
	// Assets.car. Public UIImage lookup cannot cross from iOS into another
	// bundle's tvOS brand assets.
	if let image = tvOSIconTest(bundleURL, uniqueNames), image.size.width > 1 {
		return image
	}

	for name in uniqueNames {
		if let image = _tvOSAsset(named: name, in: bundle) {
			return image
		}
	}

	let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
	let candidates = (FileManager.default.enumerator(
		at: bundleURL,
		includingPropertiesForKeys: keys,
		options: [.skipsHiddenFiles]
	) as? FileManager.DirectoryEnumerator)?
		.compactMap { $0 as? URL }
		.filter {
			let path = $0.path.lowercased()
			let name = $0.lastPathComponent.lowercased()
			return $0.pathExtension.lowercased() == "png" &&
				!path.contains("/frameworks/") &&
				!path.contains("/plugins/") &&
				!name.contains("top shelf") &&
				!name.contains("topshelf") &&
				!name.contains("launch") &&
				!name.contains("splash")
		} ?? []

	return candidates
		.compactMap { url -> (UIImage, CGFloat)? in
			guard let image = UIImage(contentsOfFile: url.path), image.size.width > 1, image.size.height > 1 else {
				return nil
			}
			let iconBonus: CGFloat = url.lastPathComponent.localizedCaseInsensitiveContains("icon") ? 1_000_000_000 : 0
			return (image, iconBonus + image.size.width * image.size.height)
		}
		.max(by: { $0.1 < $1.1 })?.0
}

private func _uniqueIconNames(_ names: [String]) -> [String] {
	var seen = Set<String>()
	return names.filter { !$0.isEmpty && seen.insert($0).inserted }
}

private func _tvOSAsset(named name: String, in bundle: Bundle) -> UIImage? {
	if let image = UIImage(named: name, in: bundle, compatibleWith: nil), image.size.width > 1 {
		return image
	}

	// A compiled .brandassets icon exposes each layer as
	// "<brand name>/<layer>/Content". UIKit does not synthesize the complete
	// stack when loading another app's bundle, so composite those renditions.
	let layerRoles = ["Background", "Middle", "Foreground"]
	let layers = layerRoles.compactMap { role -> UIImage? in
		for candidate in ["\(name)/\(role)/Content", "\(name)/\(role)"] {
			if let image = UIImage(named: candidate, in: bundle, compatibleWith: nil), image.size.width > 1 {
				return image
			}
		}
		return nil
	}

	guard !layers.isEmpty else { return nil }
	guard let canvasSize = layers.max(by: {
		$0.size.width * $0.size.height < $1.size.width * $1.size.height
	})?.size else {
		return nil
	}

	let format = UIGraphicsImageRendererFormat.default()
	format.scale = 1
	format.opaque = false
	return UIGraphicsImageRenderer(size: canvasSize, format: format).image { _ in
		for layer in layers {
			let scale = min(canvasSize.width / layer.size.width, canvasSize.height / layer.size.height)
			let size = CGSize(width: layer.size.width * scale, height: layer.size.height * scale)
			let origin = CGPoint(x: (canvasSize.width - size.width) / 2, y: (canvasSize.height - size.height) / 2)
			layer.draw(in: CGRect(origin: origin, size: size))
		}
	}
}

struct FRAppIconView: View {
	private let app: AppInfoPresentable?
	private let size: CGFloat

	@Environment(\.colorScheme) private var colorScheme
	@StateObject private var loader = FRAppIconLoader()

	@AppStorage("Feather.userTintColor") private var selectedColorHex: String = "#FFFFFF"
	@AppStorage("Feather.shouldTintIcons") private var shouldTintIcons: Bool = false
	@AppStorage("Feather.shouldChangeIconsBasedOffStyle") private var shouldChangeIconsBasedOffStyle: Bool = false

	init(app: AppInfoPresentable? = nil, size: CGFloat = 87) {
		self.app = app
		self.size = size
	}

	private var appearance: FRIconAppearance {
		colorScheme == .dark ? .dark : .light
	}

	/// These apps are distributed by feeds that omit icon metadata, and their
	/// tvOS artwork lives in a foreign CoreUI catalog. Bundled copies of the
	/// verified artwork avoid touching that private catalog during app launch.
	private var bundledFallbackAssetName: String? {
		switch app?.identifier?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
		case "com.nulldev85.nullsports":
			return "LineupTV"
		case "com.stadiumsync.mobile":
			return "StadiumSync"
		case "com.stadiumsync.mobile.tv":
			return "StadiumSyncTV"
		default:
			return nil
		}
	}

	var body: some View {
		Group {
			if app == nil {
				Image("NullSignBrand")
					.renderingMode(.original)
					.appIconStyle(size: size)
			} else if let bundledFallbackAssetName {
				Image(bundledFallbackAssetName)
					.appIconStyle(size: size)
			} else if let image = loader.image {
				Image(uiImage: image)
					.appIconStyle(size: size)
			} else {
				Image("App_Unknown")
					.appIconStyle(size: size)
			}
		}
		.task(id: "\(app?.uuid ?? "self")\(appearance.rawValue)\(selectedColorHex)\(shouldTintIcons)\(shouldChangeIconsBasedOffStyle)") {
			if app != nil && bundledFallbackAssetName == nil {
				_load()
			} else {
				loader.cancel()
			}
		}
		.onDisappear {
			loader.cancel()
		}
	}

	private func _load() {
		let bundleURL: URL

		if let app {
			guard let url = Storage.shared.getAppDirectory(for: app) else { return }
			bundleURL = url
		} else {
			bundleURL = Bundle.main.bundleURL
		}

		loader.load(
			bundleURL: bundleURL,
			appearance: appearance,
			tint: selectedColorHex,
			isTinted: shouldTintIcons,
			dynamic: shouldChangeIconsBasedOffStyle
		)
	}

}
