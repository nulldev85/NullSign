import SwiftUI

/// Shared pieces for signing destinations. Repeated information stays in a
/// continuous list on the backdrop; cards are reserved for summaries.
struct SigningSectionHeader: View {
	let title: String
	var detail: String? = nil

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			NullSignSectionLabel(title: title)

			if let detail {
				Text(detail)
					.font(.caption)
					.foregroundStyle(NullSignStyle.muted)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.textCase(nil)
		.padding(.top, 12)
		.padding(.bottom, 4)
	}
}

struct SigningRowIcon: View {
	let systemImage: String
	var tint: Color = .white

	var body: some View {
		NullSignIconTile(systemImage: systemImage, tint: tint, size: 32)
	}
}

struct SigningEmptyState: View {
	let systemImage: String
	let title: String
	let detail: String

	var body: some View {
		VStack(spacing: 12) {
			NullSignIconTile(systemImage: systemImage, tint: NullSignStyle.muted, size: 48)
			Text(title)
				.font(.system(size: 16, weight: .bold))
			Text(detail)
				.font(.subheadline)
				.foregroundStyle(NullSignStyle.muted)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
		}
		.frame(maxWidth: .infinity)
		.padding(.horizontal, 28)
		.padding(.vertical, 30)
	}
}

struct SigningSummaryCard<Content: View>: View {
	private let content: Content

	init(@ViewBuilder content: () -> Content) {
		self.content = content()
	}

	var body: some View {
		content
			.padding(16)
			.background(
				RadialGradient(
					colors: [NullSignStyle.accent.opacity(0.16), .clear],
					center: .topLeading,
					startRadius: 2,
					endRadius: 220
				)
			)
			.nullSignSurface(cornerRadius: 22)
	}
}

extension View {
	func signingDestinationRow(
		top: CGFloat = 10,
		bottom: CGFloat = 10,
		leading: CGFloat = 16,
		trailing: CGFloat = 16
	) -> some View {
		self
			.listRowInsets(EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing))
			.listRowBackground(Color.clear)
			.listRowSeparatorTint(NullSignStyle.hairline)
	}

	func signingSummaryRow() -> some View {
		self
			.listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)
	}
}
