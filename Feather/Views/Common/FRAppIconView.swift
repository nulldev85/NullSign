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
		guard let info = NSDictionary(contentsOf: bundleURL.appendingPathComponent("Info.plist")) as? [String: Any] else {
			return nil
		}

		// An unreadable tvOS catalog must not enter IconServices' iOS recipe.
		if TVIconSelection.isTVApp(info) {
			return tvOSIcon(in: bundleURL, info: info)
		}
		return iconTest(bundleURL)
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

/// Read the package's own bitmap renditions. Do not ask UIKit/IconServices to
/// flatten a foreign tvOS layer stack, or substitute bundled copies of an icon.
private func tvOSIcon(in bundleURL: URL, info: [String: Any]) -> UIImage? {
	let names = TVIconSelection.assetNames(in: info)
	if let image = tvOSIconTest(bundleURL, names), image.size.width > 1 {
		return image
	}

	let root = bundleURL.standardizedFileURL.resolvingSymlinksInPath().path + "/"
	for name in names {
		for file in TVIconSelection.looseFileNames(for: name) {
			let url = bundleURL.appendingPathComponent(file).standardizedFileURL.resolvingSymlinksInPath()
			guard url.path.hasPrefix(root) else { continue }
			if let image = UIImage(contentsOfFile: url.path), image.size.width > 1, image.size.height > 1 {
				return image
			}
		}
	}
	return nil
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
			if app == nil {
				Image("NullSignBrand")
					.renderingMode(.original)
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
			if app != nil {
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
