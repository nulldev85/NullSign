//
//  FRAppIconView.swift
//  NullSign
//
//  Created by samara on 18.04.2025.
//

import SwiftUI

enum FRIconAppearance: Int {
	case light = 0
	case dark = 1
}

@MainActor
final class FRIconCache {
	static let shared = FRIconCache()
	private init() {}

	private let cache = NSCache<NSString, UIImage>()

	/// NSCache purges under memory pressure (which a large install triggers), blanking
	/// the icon mid-render. This bounded LRU keeps recent icons resident so they never flash.
	private var _pinned: [NSString: UIImage] = [:]
	private var _pinnedOrder: [NSString] = []
	private let _pinnedLimit = 24

	private func key(url: URL, appearance: FRIconAppearance, tint: String, isTinted: Bool, dynamic: Bool) -> NSString {
		"\(url.path)#\(appearance.rawValue)#\(tint)#\(isTinted)#\(dynamic)" as NSString
	}

	func image(for url: URL, appearance: FRIconAppearance, tint: String, isTinted: Bool, dynamic: Bool) -> UIImage? {
		let k = key(url: url, appearance: appearance, tint: tint, isTinted: isTinted, dynamic: dynamic)
		if let img = cache.object(forKey: k) { return img }
		if let img = _pinned[k] {
			cache.setObject(img, forKey: k) // repopulate tier 1 after a purge
			// Bump recency so a frequently-shown icon isn't evicted as "oldest".
			if let idx = _pinnedOrder.firstIndex(of: k) {
				_pinnedOrder.remove(at: idx)
				_pinnedOrder.append(k)
			}
			return img
		}
		return nil
	}

	func insert(_ image: UIImage, for url: URL, appearance: FRIconAppearance, tint: String, isTinted: Bool, dynamic: Bool) {
		let k = key(url: url, appearance: appearance, tint: tint, isTinted: isTinted, dynamic: dynamic)
		cache.setObject(image, forKey: k)

		if let idx = _pinnedOrder.firstIndex(of: k) {
			_pinnedOrder.remove(at: idx)
		}
		_pinnedOrder.append(k)
		_pinned[k] = image

		if _pinnedOrder.count > _pinnedLimit {
			let evict = _pinnedOrder.removeFirst()
			_pinned[evict] = nil
		}
	}

	func invalidateAll() {
		cache.removeAllObjects()
		_pinned.removeAll()
		_pinnedOrder.removeAll()
	}
}

/// Renders icons one at a time. IconServices is private API with no
/// thread-safety guarantees, and a list appearing used to start one render
/// per row at once.
private actor FRIconRenderer {
	static let shared = FRIconRenderer()

	func render(bundleURL: URL, styled: Bool, isPad: Bool) -> UIImage? {
		// The bundle can be deleted between a row appearing and this running;
		// never hand IconServices a bundle that is no longer on disk.
		guard let info = NSDictionary(contentsOf: bundleURL.appendingPathComponent("Info.plist")) as? [String: Any] else {
			return nil
		}

		// An Apple TV app's icon is a layer stack in its asset catalog, which
		// IconServices' iOS recipe can't read.
		if TVIconSelection.isTVApp(info) {
			return tvOSIcon(in: bundleURL, info: info)
		}
		let files = PhoneIconSelection.files(in: info, isPad: isPad)
		if !styled, let bitmap = looseIcon(in: bundleURL, files: files) { return bitmap }
		if let image = iconTest(bundleURL), image.size.width > 1, image.size.height > 1 { return image }
		return styled ? looseIcon(in: bundleURL, files: files) : nil
	}
}

/// Read the package's own bitmap renditions. Do not ask UIKit/IconServices to
/// flatten a foreign tvOS layer stack, or substitute bundled copies of an icon.
private func tvOSIcon(in bundleURL: URL, info: [String: Any]) -> UIImage? {
	let names = TVIconSelection.assetNames(in: info)
	if let image = tvOSIconTest(bundleURL, names), image.size.width > 1 {
		return image
	}

	return looseIcon(in: bundleURL, files: names.flatMap { TVIconSelection.looseFileNames(for: $0) })
}

private func looseIcon(in bundleURL: URL, files: [String]) -> UIImage? {
	let root = bundleURL.standardizedFileURL.resolvingSymlinksInPath().path + "/"
	for file in files {
		let url = bundleURL.appendingPathComponent(file).standardizedFileURL.resolvingSymlinksInPath()
		guard url.path.hasPrefix(root) else { continue }
		if let image = UIImage(contentsOfFile: url.path), image.size.width > 1, image.size.height > 1 {
			return image
		}
	}
	return nil
}

@MainActor
final class FRAppIconLoader: ObservableObject {
	@Published var image: UIImage?
	private var task: Task<Void, Never>?
	private var representedRequest: String?

	func load(bundleURL: URL, appearance: FRIconAppearance, tint: String, isTinted: Bool, dynamic: Bool) {
		let request = "\(bundleURL.path)#\(appearance.rawValue)#\(tint)#\(isTinted)#\(dynamic)"
		task?.cancel()
		// A reused row must not keep showing the previous app's icon.
		if representedRequest != request { image = nil }
		representedRequest = request

		if let cached = FRIconCache.shared.image(for: bundleURL, appearance: appearance, tint: tint, isTinted: isTinted, dynamic: dynamic) {
			self.image = cached
			return
		}

		task = Task {
			let generated = await FRIconRenderer.shared.render(
				bundleURL: bundleURL,
				styled: isTinted || (dynamic && appearance == .dark),
				isPad: UIDevice.current.userInterfaceIdiom == .pad
			)

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

struct FRAppIconView: View {
	private let app: AppInfoPresentable?
	private let size: CGFloat

	@Environment(\.colorScheme) private var colorScheme
	@StateObject private var loader = FRAppIconLoader()

	@AppStorage("Feather.userTintColor") private var selectedColorHex: String = Color.defaultUserTintHex
	@AppStorage("Feather.shouldTintIcons") private var shouldTintIcons: Bool = false
	@AppStorage("Feather.shouldChangeIconsBasedOffStyle") private var shouldChangeIconsBasedOffStyle: Bool = false

	init(app: AppInfoPresentable? = nil, size: CGFloat = 87) {
		self.app = app
		self.size = size
	}

	private var appearance: FRIconAppearance {
		colorScheme == .dark ? .dark : .light
	}

	private var _bundleURL: URL? {
		if let app {
			return Storage.shared.getAppDirectory(for: app)
		} else {
			return Bundle.main.bundleURL
		}
	}

	/// A fresh loader has `image == nil` until its async `.task` runs; reading the cache
	/// synchronously here shows an already-cached icon without a placeholder flash.
	private var _cachedImage: UIImage? {
		guard let bundleURL = _bundleURL else { return nil }
		return FRIconCache.shared.image(
			for: bundleURL,
			appearance: appearance,
			tint: selectedColorHex,
			isTinted: shouldTintIcons,
			dynamic: shouldChangeIconsBasedOffStyle
		)
	}

	var body: some View {
		Group {
			if app == nil {
				// NullSign itself.
				Image("NullSignBrand")
					.renderingMode(.original)
					.appIconStyle(size: size)
			} else if let image = loader.image ?? _cachedImage {
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
		guard let bundleURL = _bundleURL else { return }

		loader.load(
			bundleURL: bundleURL,
			appearance: appearance,
			tint: selectedColorHex,
			isTinted: shouldTintIcons,
			dynamic: shouldChangeIconsBasedOffStyle
		)
	}
}
