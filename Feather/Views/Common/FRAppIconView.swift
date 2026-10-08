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
	private let glowCache = NSCache<NSString, UIColor>()

	private func key(url: URL, appearance: FRIconAppearance, tint: String, isTinted: Bool, dynamic: Bool) -> NSString {
		"\(url.path)#\(appearance.rawValue)#\(tint)#\(isTinted)#\(dynamic)" as NSString
	}

	func image(for url: URL, appearance: FRIconAppearance, tint: String, isTinted: Bool, dynamic: Bool) -> UIImage? {
		cache.object(forKey: key(url: url, appearance: appearance, tint: tint, isTinted: isTinted, dynamic: dynamic))
	}

	func glow(for url: URL, appearance: FRIconAppearance, tint: String, isTinted: Bool, dynamic: Bool) -> UIColor? {
		glowCache.object(forKey: key(url: url, appearance: appearance, tint: tint, isTinted: isTinted, dynamic: dynamic))
	}

	func insert(_ image: UIImage, glow: UIColor?, for url: URL, appearance: FRIconAppearance, tint: String, isTinted: Bool, dynamic: Bool) {
		let key = key(url: url, appearance: appearance, tint: tint, isTinted: isTinted, dynamic: dynamic)
		cache.setObject(image, forKey: key)
		if let glow {
			glowCache.setObject(glow, forKey: key)
		}
	}

	func invalidateAll() {
		cache.removeAllObjects()
		glowCache.removeAllObjects()
	}
}

/// Renders icons one at a time. IconServices is private API with no
/// thread-safety guarantees, and a list appearing used to start one render
/// per row at once.
private actor FRIconRenderer {
	static let shared = FRIconRenderer()

	func render(bundleURL: URL) -> (image: UIImage, glow: UIColor?)? {
		// The bundle can be deleted between a row appearing and this running;
		// never hand IconServices a bundle that is no longer on disk.
		guard FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("Info.plist").path) else {
			return nil
		}

		guard let image = tvOSIcon(in: bundleURL) ?? iconTest(bundleURL) else {
			return nil
		}

		return (image, averageGlowColor(of: image))
	}
}

@MainActor
final class FRAppIconLoader: ObservableObject {
	@Published var image: UIImage?
	@Published var glow: Color?
	private var task: Task<Void, Never>?
	private var representedRequest: String?

	func load(bundleURL: URL, appearance: FRIconAppearance, tint: String, isTinted: Bool, dynamic: Bool) {
		let request = "\(bundleURL.path)#\(appearance.rawValue)#\(tint)#\(isTinted)#\(dynamic)"
		task?.cancel()
		representedRequest = request

		if let cached = FRIconCache.shared.image(for: bundleURL, appearance: appearance, tint: tint, isTinted: isTinted, dynamic: dynamic) {
			self.image = cached
			self.glow = FRIconCache.shared.glow(for: bundleURL, appearance: appearance, tint: tint, isTinted: isTinted, dynamic: dynamic).map(Color.init(uiColor:))
			return
		}

		image = nil
		glow = nil
		task = Task {
			let rendered = await FRIconRenderer.shared.render(bundleURL: bundleURL)

			guard !Task.isCancelled, representedRequest == request, let rendered else { return }

			FRIconCache.shared.insert(rendered.image, glow: rendered.glow, for: bundleURL, appearance: appearance, tint: tint, isTinted: isTinted, dynamic: dynamic)
			self.image = rendered.image
			self.glow = rendered.glow.map(Color.init(uiColor:))
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

/// The icon's dominant light, lifted so it reads as a glow on black.
private func averageGlowColor(of image: UIImage) -> UIColor? {
	guard let cgImage = image.cgImage else { return nil }

	let side = 12
	var pixels = [UInt8](repeating: 0, count: side * side * 4)
	let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
		guard let context = CGContext(
			data: buffer.baseAddress,
			width: side,
			height: side,
			bitsPerComponent: 8,
			bytesPerRow: side * 4,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else {
			return false
		}
		context.interpolationQuality = .medium
		context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
		return true
	}
	guard drawn else { return nil }

	var red = 0.0, green = 0.0, blue = 0.0, weight = 0.0
	for index in stride(from: 0, to: pixels.count, by: 4) {
		let alpha = Double(pixels[index + 3]) / 255
		guard alpha > 0.1 else { continue }
		red += Double(pixels[index]) / 255
		green += Double(pixels[index + 1]) / 255
		blue += Double(pixels[index + 2]) / 255
		weight += alpha
	}
	guard weight > 0 else { return nil }

	let average = UIColor(red: red / weight, green: green / weight, blue: blue / weight, alpha: 1)
	var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
	guard average.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
		return average
	}
	return UIColor(
		hue: hue,
		saturation: min(saturation * 1.25, 1),
		brightness: max(brightness, 0.65),
		alpha: 1
	)
}

struct FRAppIconView: View {
	private let app: AppInfoPresentable?
	private let size: CGFloat
	private let glow: Bool

	@Environment(\.colorScheme) private var colorScheme
	@StateObject private var loader = FRAppIconLoader()

	@AppStorage("Feather.userTintColor") private var selectedColorHex: String = "#FFFFFF"
	@AppStorage("Feather.shouldTintIcons") private var shouldTintIcons: Bool = false
	@AppStorage("Feather.shouldChangeIconsBasedOffStyle") private var shouldChangeIconsBasedOffStyle: Bool = false

	/// - Parameter glow: Lights the area behind the icon with its own color.
	init(app: AppInfoPresentable? = nil, size: CGFloat = 87, glow: Bool = false) {
		self.app = app
		self.size = size
		self.glow = glow
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
		.background {
			if glow {
				Circle()
					.fill(
						RadialGradient(
							colors: [(loader.glow ?? NullSignStyle.accent).opacity(0.5), .clear],
							center: .center,
							startRadius: 0,
							endRadius: size * 0.95
						)
					)
					.frame(width: size * 1.9, height: size * 1.9)
					.offset(y: size * 0.1)
					.allowsHitTesting(false)
					.animation(.easeOut(duration: 0.35), value: loader.glow)
			}
		}
		.task(id: "\(app?.uuid ?? "self")\(appearance.rawValue)\(selectedColorHex)\(shouldTintIcons)\(shouldChangeIconsBasedOffStyle)") {
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
