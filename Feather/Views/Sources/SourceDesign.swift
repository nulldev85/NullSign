import SwiftUI

/// Small, source-specific pieces reused throughout the Apps tab.
struct SourceSectionLabel: View {
	let title: String
	var count: Int? = nil

	var body: some View {
		HStack(alignment: .firstTextBaseline) {
			Text(title)
				.font(.headline)
			Spacer()
			if let count {
				Text(count.formatted())
					.font(.caption.weight(.semibold))
					.foregroundStyle(.secondary)
			}
		}
		.textCase(nil)
	}
}

struct SourceEmptyState: View {
	let icon: String
	let title: String
	let message: String
	var actionTitle: String? = nil
	var action: (() -> Void)? = nil

	var body: some View {
		VStack(spacing: 14) {
			ZStack {
				RoundedRectangle(cornerRadius: 18, style: .continuous)
					.fill(NullSignStyle.raisedPanel)
					.frame(width: 64, height: 64)
				Image(systemName: icon)
					.font(.system(size: 25, weight: .medium))
					.foregroundStyle(NullSignStyle.accent)
			}

			VStack(spacing: 5) {
				Text(title)
					.font(.title3.weight(.semibold))
				Text(message)
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
					.fixedSize(horizontal: false, vertical: true)
			}

			if let actionTitle, let action {
				Button(action: action) {
					Text(actionTitle)
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(.black)
						.padding(.horizontal, 18)
						.frame(height: 38)
						.background(NullSignStyle.accent)
						.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
				}
				.buttonStyle(.plain)
			}
		}
		.frame(maxWidth: 330)
		.padding(24)
	}
}
struct SourcePanelModifier: ViewModifier {
	var padding: CGFloat = 14

	func body(content: Content) -> some View {
		content
			.padding(padding)
			.nullSignSurface(cornerRadius: 16)
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
		VStack(spacing: 13) {
			ProgressView()
				.tint(NullSignStyle.accent)
			Text(label)
				.font(.subheadline)
				.foregroundStyle(.secondary)
		}
		.padding(24)
	}
}
