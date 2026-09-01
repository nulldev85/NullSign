import SwiftUI

enum NullSignStyle {
	static let cyan = Color(red: 0.0, green: 0.90, blue: 1.0)
	static let panel = Color(red: 0.035, green: 0.045, blue: 0.055)
	static let raisedPanel = Color(red: 0.065, green: 0.078, blue: 0.09)
	static let hairline = Color.white.opacity(0.08)
}

struct NullSignDashboardHeader: View {
	let signedCount: Int
	let importedCount: Int
	let hasCertificate: Bool
	let importAction: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 18) {
			HStack(alignment: .top) {
				VStack(alignment: .leading, spacing: 5) {
					Text("NULLSIGN // CONSOLE")
						.font(.system(size: 11, weight: .bold, design: .monospaced))
						.tracking(1.8)
						.foregroundStyle(NullSignStyle.cyan)
					Text("Sign without the noise.")
						.font(.system(size: 23, weight: .bold, design: .rounded))
				}

				Spacer()

				ZStack {
					Circle()
						.stroke(NullSignStyle.cyan.opacity(0.18), lineWidth: 5)
					Circle()
						.trim(from: 0.08, to: 0.82)
						.stroke(NullSignStyle.cyan, style: StrokeStyle(lineWidth: 3, lineCap: .round))
						.rotationEffect(.degrees(-90))
					Image(systemName: "signature")
						.font(.system(size: 17, weight: .bold))
						.foregroundStyle(NullSignStyle.cyan)
				}
				.frame(width: 48, height: 48)
			}

			HStack(spacing: 0) {
				_metric(value: signedCount, label: "SIGNED")
				Divider().overlay(NullSignStyle.hairline).padding(.vertical, 3)
				_metric(value: importedCount, label: "QUEUED")
				Divider().overlay(NullSignStyle.hairline).padding(.vertical, 3)
				VStack(alignment: .leading, spacing: 4) {
					HStack(spacing: 6) {
						Circle()
							.fill(hasCertificate ? NullSignStyle.cyan : .orange)
							.frame(width: 7, height: 7)
						Text(hasCertificate ? "READY" : "NO CERT")
							.font(.system(size: 12, weight: .bold, design: .monospaced))
					}
					Text("IDENTITY")
						.font(.system(size: 9, weight: .semibold, design: .monospaced))
						.foregroundStyle(.secondary)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(.leading, 16)
			}

			Button(action: importAction) {
				HStack {
					Image(systemName: "plus")
					Text("IMPORT IPA")
						.font(.system(size: 13, weight: .bold, design: .monospaced))
					Spacer()
					Image(systemName: "arrow.down.to.line.compact")
				}
				.foregroundStyle(.black)
				.padding(.horizontal, 16)
				.frame(height: 44)
				.background(NullSignStyle.cyan)
				.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
			}
			.buttonStyle(.plain)
		}
		.padding(18)
		.background(
			ZStack(alignment: .topTrailing) {
				RoundedRectangle(cornerRadius: 22, style: .continuous)
					.fill(NullSignStyle.panel)
				RoundedRectangle(cornerRadius: 22, style: .continuous)
					.stroke(NullSignStyle.hairline, lineWidth: 1)
				LinearGradient(
					colors: [NullSignStyle.cyan.opacity(0.16), .clear],
					startPoint: .topTrailing,
					endPoint: .center
				)
				.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
			}
		)
		.listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 14, trailing: 16))
		.listRowBackground(Color.clear)
		.listRowSeparator(.hidden)
	}

	private func _metric(value: Int, label: String) -> some View {
		VStack(alignment: .leading, spacing: 2) {
			Text(value.description)
				.font(.system(size: 20, weight: .bold, design: .rounded))
			Text(label)
				.font(.system(size: 9, weight: .semibold, design: .monospaced))
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

struct NullSignSigningHeader: View {
	let app: AppInfoPresentable

	var body: some View {
		VStack(spacing: 14) {
			HStack(spacing: 14) {
				FRAppIconView(app: app, size: 54)
				VStack(alignment: .leading, spacing: 3) {
					Text("SIGNING SESSION")
						.font(.system(size: 10, weight: .bold, design: .monospaced))
						.tracking(1.5)
						.foregroundStyle(NullSignStyle.cyan)
					Text(app.name ?? "Unknown App")
						.font(.system(size: 19, weight: .bold, design: .rounded))
						.lineLimit(1)
					Text(app.identifier ?? "No bundle identifier")
						.font(.system(size: 11, design: .monospaced))
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}
				Spacer()
			}

			HStack(spacing: 7) {
				_step("01", "PREP")
				_line
				_step("02", "SIGN")
				_line
				_step("03", "VERIFY")
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
			Text(number).foregroundStyle(NullSignStyle.cyan)
			Text(label).foregroundStyle(.secondary)
		}
		.font(.system(size: 9, weight: .bold, design: .monospaced))
	}

	private var _line: some View {
		Rectangle()
			.fill(NullSignStyle.cyan.opacity(0.25))
			.frame(height: 1)
			.frame(maxWidth: .infinity)
	}
}

struct NullSignPanelModifier: ViewModifier {
	func body(content: Content) -> some View {
		content
			.padding(.vertical, 10)
			.padding(.horizontal, 12)
			.background(
				RoundedRectangle(cornerRadius: 16, style: .continuous)
					.fill(NullSignStyle.panel)
					.overlay(alignment: .leading) {
						Capsule()
							.fill(NullSignStyle.cyan.opacity(0.8))
							.frame(width: 2, height: 28)
							.padding(.leading, 1)
					}
					.overlay {
						RoundedRectangle(cornerRadius: 16, style: .continuous)
							.stroke(NullSignStyle.hairline, lineWidth: 1)
					}
			)
			.listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)
	}
}

extension View {
	func nullSignPanel() -> some View { modifier(NullSignPanelModifier()) }
}
