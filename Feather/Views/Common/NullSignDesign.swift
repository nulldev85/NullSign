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
		.background(
			RoundedRectangle(cornerRadius: 14, style: .continuous)
				.fill(NullSignStyle.panel)
				.overlay {
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.stroke(NullSignStyle.hairline, lineWidth: 1)
				}
		)
		.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
							.foregroundStyle(NullSignStyle.ink)
							.background(NullSignStyle.accent)
							.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
					}
					.buttonStyle(.plain)

					Button(action: importURL) {
						Label("Paste URL", systemImage: "link")
							.font(.system(size: 15, weight: .medium))
							.padding(.horizontal, 17)
							.padding(.vertical, 13)
							.background(NullSignStyle.panel)
							.overlay {
								RoundedRectangle(cornerRadius: 12, style: .continuous)
									.stroke(NullSignStyle.hairline, lineWidth: 1)
							}
							.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
					}
					.buttonStyle(.plain)
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
		VStack(spacing: 14) {
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

			HStack(spacing: 7) {
				_step("1", "Prepare")
				_line
				_step("2", "Sign")
				_line
				_step("3", "Verify")
			}
		}
		.padding(16)
		.background(NullSignStyle.panel)
		.overlay {
			RoundedRectangle(cornerRadius: 18, style: .continuous)
				.stroke(NullSignStyle.hairline, lineWidth: 1)
		}
		.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
		.listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))
		.listRowBackground(Color.clear)
		.listRowSeparator(.hidden)
	}

	private func _step(_ number: String, _ label: String) -> some View {
		HStack(spacing: 5) {
			Text(number).foregroundStyle(NullSignStyle.accent)
			Text(label).foregroundStyle(.secondary)
		}
		.font(.system(size: 10, weight: .semibold))
	}

	private var _line: some View {
		Rectangle()
			.fill(NullSignStyle.accent.opacity(0.25))
			.frame(height: 1)
			.frame(maxWidth: .infinity)
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
