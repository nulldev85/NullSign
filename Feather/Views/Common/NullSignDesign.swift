import SwiftUI

enum NullSignStyle {
	static let accent = Color.white
	static let ink = Color.black
	static let warning = Color.white.opacity(0.46)
	static let panel = Color.white.opacity(0.055)
	static let raisedPanel = Color.white.opacity(0.09)
	static let hairline = Color.white.opacity(0.10)
	static let muted = Color.white.opacity(0.60)
	static let crimson = Color(red: 0.843, green: 0.098, blue: 0.247)
}

/// Shared fill + hairline-stroke card background used across the Library, Sources,
/// Settings, and Signing screens.
struct NullSignSurfaceModifier: ViewModifier {
	var cornerRadius: CGFloat = 16
	var fill: Color = NullSignStyle.panel

	func body(content: Content) -> some View {
		content
			.background(fill)
			.overlay {
				RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
					.stroke(NullSignStyle.hairline, lineWidth: 1)
			}
			.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
	}
}

extension View {
	func nullSignSurface(cornerRadius: CGFloat = 16, fill: Color = NullSignStyle.panel) -> some View {
		modifier(NullSignSurfaceModifier(cornerRadius: cornerRadius, fill: fill))
	}
}

/// Shared button treatment: a faint vertical gradient and a fine edge give the
/// fill some depth, and the button settles slightly while pressed. Callers keep
/// their own padding and frame; the style supplies fill, shape, and feedback.
struct NullSignButtonStyle: ButtonStyle {
	enum Prominence {
		case primary
		case secondary
	}

	var prominence: Prominence = .primary
	var cornerRadius: CGFloat = 11
	/// Extends the tappable area vertically past the drawn fill, for compact buttons in rows.
	var minTapHeight: CGFloat = 0
	/// Off for buttons that are disabled only while their own work is running and
	/// already show that with a spinner.
	var dimsWhenDisabled: Bool = true

	func makeBody(configuration: Configuration) -> some View {
		NullSignButtonBody(
			configuration: configuration,
			prominence: prominence,
			cornerRadius: cornerRadius,
			minTapHeight: minTapHeight,
			dimsWhenDisabled: dimsWhenDisabled
		)
	}
}

extension ButtonStyle where Self == NullSignButtonStyle {
	static func nullSign(
		_ prominence: NullSignButtonStyle.Prominence = .primary,
		cornerRadius: CGFloat = 11,
		minTapHeight: CGFloat = 0,
		dimsWhenDisabled: Bool = true
	) -> NullSignButtonStyle {
		NullSignButtonStyle(
			prominence: prominence,
			cornerRadius: cornerRadius,
			minTapHeight: minTapHeight,
			dimsWhenDisabled: dimsWhenDisabled
		)
	}
}

private struct NullSignButtonBody: View {
	let configuration: ButtonStyleConfiguration
	let prominence: NullSignButtonStyle.Prominence
	let cornerRadius: CGFloat
	let minTapHeight: CGFloat
	let dimsWhenDisabled: Bool

	@Environment(\.isEnabled) private var _isEnabled
	@Environment(\.accessibilityReduceMotion) private var _reduceMotion

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
		let isPressed = configuration.isPressed

		configuration.label
			.foregroundStyle(prominence == .primary ? NullSignStyle.ink : NullSignStyle.accent)
			.background {
				ZStack {
					_fill
					_pressedTint.opacity(isPressed ? 1 : 0)
				}
			}
			.overlay {
				shape.strokeBorder(_edge, lineWidth: 1)
			}
			.clipShape(shape)
			.opacity(_isEnabled || !dimsWhenDisabled ? 1 : 0.45)
			.scaleEffect(isPressed && !_reduceMotion ? 0.97 : 1)
			.animation(_reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.82), value: isPressed)
			.frame(minHeight: minTapHeight)
			.contentShape(Rectangle())
	}

	private var _fill: LinearGradient {
		switch prominence {
		case .primary:
			LinearGradient(colors: [Color(white: 1), Color(white: 0.87)], startPoint: .top, endPoint: .bottom)
		case .secondary:
			LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom)
		}
	}

	/// Light catches the top edge on dark fills; white fills get a soft lower lip instead.
	private var _edge: LinearGradient {
		switch prominence {
		case .primary:
			LinearGradient(colors: [Color.white, Color.black.opacity(0.14)], startPoint: .top, endPoint: .bottom)
		case .secondary:
			LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom)
		}
	}

	private var _pressedTint: Color {
		switch prominence {
		case .primary: Color.black.opacity(0.12)
		case .secondary: Color.white.opacity(0.07)
		}
	}
}

struct NullSignLibrarySummary: View {
	let signedCount: Int
	let importedCount: Int
	let hasCertificate: Bool

	var body: some View {
		HStack(spacing: 16) {
			_metric(value: signedCount, label: "Signed")
			_metric(value: importedCount, label: "Unsigned")
			Spacer(minLength: 4)
			HStack(spacing: 7) {
				Circle()
					.fill(hasCertificate ? NullSignStyle.accent : NullSignStyle.warning)
					.frame(width: 7, height: 7)
				Text(hasCertificate ? "Certificate ready" : "Certificate needed")
					.font(.system(size: 12, weight: .medium))
					.foregroundStyle(NullSignStyle.muted)
			}
		}
		.padding(.horizontal, 16)
		.frame(height: 58)
		.nullSignSurface(cornerRadius: 14)
		.listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 12, trailing: 16))
		.listRowBackground(Color.clear)
		.listRowSeparator(.hidden)
	}

	private func _metric(value: Int, label: String) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: 5) {
			Text(value.description).font(.system(size: 17, weight: .semibold))
			Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(NullSignStyle.muted)
		}
	}
}

struct NullSignEmptySignerView: View {
	let hasCertificate: Bool
	let importFile: () -> Void
	let importURL: () -> Void

	var body: some View {
		VStack(spacing: 0) {
			Spacer(minLength: 36)
			VStack(spacing: 18) {
				ZStack {
					RoundedRectangle(cornerRadius: 18, style: .continuous)
						.fill(NullSignStyle.panel)
						.frame(width: 72, height: 72)
					Image(systemName: "app.dashed")
						.font(.system(size: 30, weight: .light))
						.foregroundStyle(NullSignStyle.accent)
				}
				VStack(spacing: 7) {
					Text("Import an app to begin")
						.font(.system(size: 24, weight: .semibold))
					Text("NullSign checks the package before it signs anything.")
						.font(.subheadline)
						.foregroundStyle(NullSignStyle.muted)
						.multilineTextAlignment(.center)
				}

				HStack(spacing: 10) {
					Button(action: importFile) {
						Label("Choose IPA", systemImage: "folder")
							.font(.system(size: 15, weight: .semibold))
							.padding(.horizontal, 17)
							.padding(.vertical, 13)
					}
					.buttonStyle(.nullSign(cornerRadius: 12))

					Button(action: importURL) {
						Label("Paste URL", systemImage: "link")
							.font(.system(size: 15, weight: .medium))
							.padding(.horizontal, 17)
							.padding(.vertical, 13)
					}
					.buttonStyle(.nullSign(.secondary, cornerRadius: 12))
				}

				HStack(spacing: 7) {
					Circle().fill(hasCertificate ? NullSignStyle.accent : NullSignStyle.warning).frame(width: 6, height: 6)
					Text(hasCertificate ? "Signing certificate ready" : "Import a certificate in Settings before signing")
						.font(.footnote)
						.foregroundStyle(NullSignStyle.muted)
				}
			}
			.padding(.horizontal, 28)
			Spacer(minLength: 40)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color.black)
	}
}

struct NullSignSigningHeader: View {
	let app: AppInfoPresentable

	var body: some View {
		HStack(spacing: 14) {
			FRAppIconView(app: app, size: 54)
			VStack(alignment: .leading, spacing: 3) {
				HStack(spacing: 7) {
					Text("Signing session")
						.font(.system(size: 11, weight: .semibold))
						.foregroundStyle(NullSignStyle.accent)
					PlatformBadge(platform: app.platform)
				}
				Text(app.name ?? "Unknown App")
					.font(.system(size: 19, weight: .bold))
					.lineLimit(1)
				Text(app.identifier ?? "No bundle identifier")
					.font(.system(size: 11, design: .monospaced))
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
			Spacer()
		}
		.padding(16)
		.nullSignSurface(cornerRadius: 18)
		.listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))
		.listRowBackground(Color.clear)
		.listRowSeparator(.hidden)
	}
}

struct NullSignPanelModifier: ViewModifier {
	func body(content: Content) -> some View {
		content
			.padding(.vertical, 11)
			.padding(.leading, 10)
			.background(
				Color.black
					.overlay(alignment: .leading) {
						Rectangle().fill(NullSignStyle.accent.opacity(0.7)).frame(width: 2, height: 30)
					}
					.overlay(alignment: .bottom) {
						Rectangle().fill(NullSignStyle.hairline).frame(height: 1)
					}
			)
			.listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)
	}
}

extension View {
	func nullSignPanel() -> some View { modifier(NullSignPanelModifier()) }
}
