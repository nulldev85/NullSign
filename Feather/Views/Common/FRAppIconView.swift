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
			let generated = await Task.detached(priority: .userInitiated) {
				return tvOSIcon(in: bundleURL) ?? iconTest(bundleURL)
			}.value

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
/// IconServices expects. Ask the imported bundle's asset catalog for the
/// declared brand asset first, then fall back to any bundled square artwork.
private func tvOSIcon(in bundleURL: URL) -> UIImage? {
	guard let bundle = Bundle(url: bundleURL) else { return nil }
	let families = bundle.object(forInfoDictionaryKey: "UIDeviceFamily") as? [Int] ?? []
	let platforms = bundle.object(forInfoDictionaryKey: "CFBundleSupportedPlatforms") as? [String] ?? []
	guard families.contains(3) || platforms.contains(where: { $0.localizedCaseInsensitiveContains("appletv") }) else {
		return nil
	}

	var names: [String] = []
	if let icons = bundle.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
	   let primary = icons["CFBundlePrimaryIcon"] as? [String: Any] {
		if let name = primary["CFBundleIconName"] as? String { names.append(name) }
		if let files = primary["CFBundleIconFiles"] as? [String] { names.append(contentsOf: files.reversed()) }
	}
	names.append(contentsOf: ["App Icon", "App Icon - Small", "AppIcon"])

	for name in names where !name.isEmpty {
		if let image = UIImage(named: name, in: bundle, compatibleWith: nil), image.size.width > 1 {
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
			$0.pathExtension.lowercased() == "png" &&
			!$0.lastPathComponent.localizedCaseInsensitiveContains("top shelf") &&
			!$0.lastPathComponent.localizedCaseInsensitiveContains("topshelf")
		} ?? []

	return candidates
		.compactMap { url -> (UIImage, CGFloat)? in
			guard let image = UIImage(contentsOfFile: url.path), image.size.width == image.size.height else { return nil }
			return (image, image.size.width)
		}
		.max(by: { $0.1 < $1.1 })?.0
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

	var body: some View {
		Group {
			if let image = loader.image {
				Image(uiImage: image)
					.appIconStyle(size: size)
			} else {
				Image("App_Unknown")
					.appIconStyle(size: size)
			}
		}
		.task(id: "\(appearance.rawValue)\(selectedColorHex)\(shouldTintIcons)\(shouldChangeIconsBasedOffStyle)") {
			_load()
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
