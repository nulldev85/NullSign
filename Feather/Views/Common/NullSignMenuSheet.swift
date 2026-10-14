import SwiftUI
import NimbleViews

/// Shared branded presentation for choices that otherwise use unstyled system menus.
struct NullSignMenuSheet<Content: View>: View {
	@Environment(\.dismiss) private var dismiss
	let title: String
	let systemImage: String
	var detail: String? = nil
	let detents: Set<PresentationDetent>
	private let content: Content

	init(
		title: String,
		systemImage: String,
		detail: String? = nil,
		detents: Set<PresentationDetent> = [.fraction(0.6), .large],
		@ViewBuilder content: () -> Content
	) {
		self.title = title
		self.systemImage = systemImage
		self.detail = detail
		self.detents = detents
		self.content = content()
	}

	var body: some View {
		NBNavigationView(title, displayMode: .inline) {
			ScrollView {
				VStack(alignment: .leading, spacing: 22) {
					if let detail {
						NullSignSettingsIntro(systemImage: systemImage, title: title, detail: detail)
					}
					content
				}
				.padding(.horizontal, 20)
				.padding(.top, 16)
				.padding(.bottom, 28)
			}
			.scrollDismissesKeyboard(.interactively)
			.nullSignPage()
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button { dismiss() } label: {
						Image(systemName: "xmark")
							.font(.roundedUI(size: 15, weight: .bold))
							.foregroundStyle(.white)
							.frame(width: 36, height: 36)
							.background(NullSignStyle.fill, in: Circle())
							.frame(width: 44, height: 44)
							.contentShape(Circle())
					}
					.buttonStyle(.plain)
					.accessibilityLabel(.localized("Close"))
				}
			}
		}
		.nullSignTypography()
		.preferredColorScheme(.dark)
		.tint(NullSignStyle.accent)
		.presentationDetents(detents)
		.presentationDragIndicator(.visible)
		.modifier(NullSignSheetChrome())
	}
}

struct NullSignSheetChrome: ViewModifier {
	@ViewBuilder
	func body(content: Content) -> some View {
		if #available(iOS 16.4, *) {
			content
				.presentationBackground(NullSignStyle.canvas)
				.presentationCornerRadius(32)
		} else {
			content
		}
	}
}

struct NullSignMenuAction: View {
	let title: String
	let systemImage: String
	var detail: String? = nil
	var tint: Color = NullSignStyle.accent
	var isDestructive = false
	var isSelected = false
	var selectionImage = "checkmark"
	var isDisabled = false
	let action: () -> Void

	var body: some View {
		Button(role: isDestructive ? .destructive : nil, action: action) {
			HStack(spacing: 12) {
				NullSignIconTile(
					systemImage: systemImage,
					tint: isDestructive ? NullSignStyle.danger : tint,
					size: 32, filled: true
				)
				.accessibilityHidden(true)
				VStack(alignment: .leading, spacing: 3) {
					Text(title)
						.font(.roundedUI(.body, weight: .bold))
						.foregroundStyle(isDestructive ? NullSignStyle.danger : Color.white)
						.fixedSize(horizontal: false, vertical: true)
					if let detail {
						Text(detail)
							.font(.roundedUI(.footnote))
							.foregroundStyle(NullSignStyle.muted)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
				Spacer(minLength: 8)
				if isSelected {
					Image(systemName: selectionImage)
						.font(.roundedUI(size: 15, weight: .bold))
						.foregroundStyle(NullSignStyle.accent)
						.accessibilityHidden(true)
				}
			}
			.padding(.vertical, 8)
			.frame(minHeight: 52)
			.frame(maxWidth: .infinity, alignment: .leading)
			.contentShape(Rectangle())
		}
		.buttonStyle(NullSignPressableStyle())
		.disabled(isDisabled)
		.opacity(isDisabled ? 0.45 : 1)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}
}
