import SwiftUI

/// Shared pieces for signing destinations. Repeated information stays in a
/// continuous list; cards are reserved for summaries.
struct SigningSectionHeader: View {
	let title: String
	var detail: String? = nil

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			NullSignSectionLabel(title: title)

			if let detail {
				Text(detail)
					.font(.footnote)
					.foregroundStyle(NullSignStyle.faint)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.textCase(nil)
		.padding(.top, 10)
		.padding(.bottom, 4)
	}
}

struct SigningRowIcon: View {
	let systemImage: String
	var tint: Color = .white

	var body: some View {
		NullSignIconTile(systemImage: systemImage, tint: tint, size: 30)
	}
}

struct SigningEmptyState: View {
	let systemImage: String
	let title: String
	let detail: String

	var body: some View {
		VStack(spacing: 10) {
			Image(systemName: systemImage)
				.font(.system(size: 30, weight: .regular))
				.foregroundStyle(NullSignStyle.faint)
			Text(title)
				.font(.headline)
			Text(detail)
				.font(.subheadline)
				.foregroundStyle(NullSignStyle.muted)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
		}
		.frame(maxWidth: .infinity)
		.padding(.horizontal, 28)
		.padding(.vertical, 28)
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
			.nullSignSurface()
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
