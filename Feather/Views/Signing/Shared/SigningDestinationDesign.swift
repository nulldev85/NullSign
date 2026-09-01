import SwiftUI

/// Shared pieces for signing destinations. Repeated information stays in a
/// continuous list; elevated surfaces are reserved for summaries and actions.
struct SigningSectionHeader: View {
	let title: String
	var detail: String? = nil

	var body: some View {
		VStack(alignment: .leading, spacing: 3) {
			Text(title.uppercased())
				.font(.caption.weight(.semibold))
				.tracking(0.55)
				.foregroundStyle(.secondary)

			if let detail {
				Text(detail)
					.font(.caption)
					.foregroundStyle(NullSignStyle.muted)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.textCase(nil)
		.padding(.top, 8)
		.padding(.bottom, 4)
	}
}

struct SigningRowIcon: View {
	let systemImage: String
	var tint: Color = NullSignStyle.cyan

	var body: some View {
		Image(systemName: systemImage)
			.font(.system(size: 15, weight: .semibold))
			.foregroundStyle(tint)
			.frame(width: 30, height: 30)
			.background(NullSignStyle.raisedPanel)
			.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
	}
}

struct SigningEmptyState: View {
	let systemImage: String
	let title: String
	let detail: String

	var body: some View {
		VStack(spacing: 10) {
			Image(systemName: systemImage)
				.font(.system(size: 25, weight: .light))
				.foregroundStyle(NullSignStyle.cyan)
			Text(title)
				.font(.headline)
			Text(detail)
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
		}
		.frame(maxWidth: .infinity)
		.padding(.horizontal, 28)
		.padding(.vertical, 32)
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
			.background(NullSignStyle.panel)
			.overlay(alignment: .leading) {
				Rectangle()
					.fill(NullSignStyle.cyan)
					.frame(width: 2)
			}
			.overlay {
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.stroke(NullSignStyle.hairline, lineWidth: 1)
			}
			.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
			.listRowBackground(Color.black)
			.listRowSeparatorTint(NullSignStyle.hairline)
	}

	func signingSummaryRow() -> some View {
		self
			.listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))
			.listRowBackground(Color.black)
			.listRowSeparator(.hidden)
	}
}
