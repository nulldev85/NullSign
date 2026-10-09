import SwiftUI
import NukeUI

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
	var size: CGFloat = 50
	var placeholderSystemImage: String = "shippingbox"

	var body: some View {
		Group {
			if let url {
				LazyImageIcon(url: url, size: size, placeholderSystemImage: placeholderSystemImage)
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
	let size: CGFloat
	var placeholderSystemImage: String = "shippingbox"

	var body: some View {
		LazyImage(url: url) { state in
			if let image = state.image {
				image.appIconStyle(size: size, isCircle: false, background: NullSignStyle.raisedPanel)
			} else {
				SourceIconPlaceholder(size: size, systemImage: placeholderSystemImage)
			}
		}
	}
}
