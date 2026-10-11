import SwiftUI
import Nuke
import NukeUI

/// Source feeds in the wild frequently use repository-relative paths or a
/// GitHub asset page instead of a direct image URL. Resolve those forms in one
/// place so every source screen displays the same icon.
enum SourceAssetURL {
	private static let _inlineImageCache = NSCache<NSString, UIImage>()

	static func resolve(_ url: URL?, relativeTo sourceURL: URL?) -> URL? {
		guard let url else { return nil }
		let rawValue = url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !rawValue.isEmpty else { return nil }

		if rawValue.hasPrefix("//") {
			let scheme = sourceURL?.scheme ?? "https"
			return URL(string: "\(scheme):\(rawValue)").flatMap(_normalizedRemoteURL)
		}

		if url.scheme == nil {
			guard let sourceURL else { return nil }
			guard let resolvedURL = URL(string: rawValue, relativeTo: sourceURL)?.absoluteURL else { return nil }
			return _normalizedRemoteURL(resolvedURL)
		}

		return _normalizedRemoteURL(url)
	}

	static func inlineImage(from url: URL) -> UIImage? {
		guard url.scheme?.lowercased() == "data" else { return nil }
		let key = url.absoluteString as NSString
		if let cached = _inlineImageCache.object(forKey: key) { return cached }

		let value = url.absoluteString
		guard let comma = value.firstIndex(of: ",") else { return nil }
		let metadata = value[value.startIndex..<comma].lowercased()
		let payload = String(value[value.index(after: comma)...])
		let data: Data?
		if metadata.contains(";base64") {
			data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters)
		} else if let decoded = payload.removingPercentEncoding {
			data = decoded.data(using: .utf8)
		} else {
			data = nil
		}

		guard let data, let image = UIImage(data: data) else { return nil }
		_inlineImageCache.setObject(image, forKey: key)
		return image
	}

	private static func _normalizedRemoteURL(_ url: URL) -> URL? {
		guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return url }

		// ATS rejects ordinary HTTP image requests. Most source CDNs offer HTTPS,
		// so prefer it without weakening transport security for the entire app.
		if components.scheme?.lowercased() == "http" {
			components.scheme = "https"
		}

		guard components.host?.lowercased() == "github.com" else {
			return components.url
		}

		let path = components.path.split(separator: "/", omittingEmptySubsequences: true)
		guard path.count >= 5, path[2] == "blob" || path[2] == "raw" else {
			return components.url
		}

		var raw = URLComponents()
		raw.scheme = "https"
		raw.host = "raw.githubusercontent.com"
		raw.path = "/" + ([path[0], path[1]] + Array(path.dropFirst(3))).joined(separator: "/")
		return raw.url
	}
}

/// Small, source-specific pieces reused throughout the Apps tab.
struct SourceSectionLabel: View {
	let title: String
	var count: Int? = nil
	var prominent: Bool = true

	var body: some View {
		NullSignSectionLabel(title: title, count: count, prominent: prominent)
	}
}

struct SourceEmptyState: View {
	let icon: String
	let title: String
	let message: String
	var actionTitle: String? = nil
	var action: (() -> Void)? = nil

	var body: some View {
		NullSignEmptyState(systemImage: icon, title: title, message: message) {
			if let actionTitle, let action {
				Button(action: action) {
					Text(actionTitle)
						.frame(minWidth: 160)
				}
				.buttonStyle(NullSignPrimaryButtonStyle(height: 44))
				.padding(.top, 4)
			}
		}
	}
}

struct SourcePanelModifier: ViewModifier {
	var padding: CGFloat = 14

	func body(content: Content) -> some View {
		content
			.padding(padding)
			.nullSignSurface()
	}
}

extension View {
	func sourcePanel(padding: CGFloat = 14) -> some View {
		modifier(SourcePanelModifier(padding: padding))
	}
}

struct SourceLoadingState: View {
	var label: String = "Loading apps"

	var body: some View {
		VStack(spacing: 12) {
			ProgressView()
			Text(label)
				.font(.subheadline)
				.foregroundStyle(NullSignStyle.muted)
		}
		.padding(24)
	}
}

/// Overlapping repository icons, used to preview a catalog at a glance.
struct SourceIconStack: View {
	let urls: [URL]
	var size: CGFloat = 34

	var body: some View {
		HStack(spacing: -size * 0.32) {
			ForEach(Array(urls.prefix(4).enumerated()), id: \.offset) { index, url in
				SourceRemoteIcon(url: url, size: size)
					.overlay(
						RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
							.strokeBorder(Color.black, lineWidth: 2)
					)
					.zIndex(Double(4 - index))
			}
		}
	}
}

/// A remote icon in NullSign's app-icon shape with a quiet placeholder.
struct SourceRemoteIcon: View {
	let url: URL?
	var relativeTo: URL? = nil
	var size: CGFloat = 50
	var placeholderSystemImage: String = "shippingbox"

	var body: some View {
		let resolvedURL = SourceAssetURL.resolve(url, relativeTo: relativeTo)

		Group {
			if let url = resolvedURL,
			   let image = SourceAssetURL.inlineImage(from: url) {
				Image(uiImage: image)
					.appIconStyle(size: size, isCircle: false, background: NullSignStyle.raisedPanel)
			} else if let url = resolvedURL {
				LazyImageIcon(
					url: url,
					referer: relativeTo,
					size: size,
					placeholderSystemImage: placeholderSystemImage
				)
			} else {
				_placeholder
			}
		}
		.frame(width: size, height: size)
	}

	private var _placeholder: some View {
		SourceIconPlaceholder(size: size, systemImage: placeholderSystemImage)
	}
}

struct SourceIconPlaceholder: View {
	let size: CGFloat
	var systemImage: String = "shippingbox"

	var body: some View {
		ZStack {
			RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
				.fill(NullSignStyle.fill)
			Image(systemName: systemImage)
				.font(.system(size: size * 0.38, weight: .medium))
				.foregroundStyle(NullSignStyle.faint)
		}
		.frame(width: size, height: size)
	}
}

/// A remote image loaded through Nuke, shaped like an app icon.
struct LazyImageIcon: View {
	let url: URL
	var referer: URL? = nil
	let size: CGFloat
	var placeholderSystemImage: String = "shippingbox"

	private var request: ImageRequest {
		var urlRequest = URLRequest(url: url)
		urlRequest.setValue("image/avif,image/webp,image/apng,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
		urlRequest.setValue(
			"Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148",
			forHTTPHeaderField: "User-Agent"
		)
		if let referer,
		   var components = URLComponents(url: referer, resolvingAgainstBaseURL: true) {
			components.path = "/"
			components.query = nil
			components.fragment = nil
			urlRequest.setValue(components.url?.absoluteString, forHTTPHeaderField: "Referer")
		}
		return ImageRequest(urlRequest: urlRequest)
	}

	var body: some View {
		LazyImage(request: request) { state in
			if let image = state.image {
				image.appIconStyle(size: size, isCircle: false, background: NullSignStyle.raisedPanel)
			} else {
				SourceIconPlaceholder(size: size, systemImage: placeholderSystemImage)
			}
		}
	}
}
