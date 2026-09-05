import SwiftUI
import UIKit
import NimbleViews

struct DiagnosticsView: View {
	@State private var _logExists = false

	var body: some View {
		ScrollView {
			VStack(spacing: 22) {
				NullSignSettingsIntro(
					systemImage: "waveform.path.ecg",
					title: "Local Diagnostics",
					detail: _logExists
						? "A signing log is available to review or share."
						: "No signing events have been recorded yet.",
					status: _logExists ? "Log available" : "Empty",
					statusColor: _logExists ? NullSignStyle.accent : Color.secondary
				)

				NullSignSettingsSection(
					"Signing Log",
					detail: "Logs stay on this iPhone. NullSign removes its app-container path and does not record certificate passwords or private keys."
				) {
					Button {
						UIActivityViewController.show(activityItems: [ReliabilityCenter.shared.logURL])
					} label: {
						NullSignSettingsRow(
							title: "Export Diagnostic Log",
							detail: "Share a plain-text copy",
							systemImage: "square.and.arrow.up",
							showsChevron: false
						)
					}
					.buttonStyle(.plain)
					.disabled(!_logExists)
					.opacity(_logExists ? 1 : 0.45)

					NullSignSettingsDivider()

					Button {
						ReliabilityCenter.shared.clearLog()
						_refresh()
					} label: {
						NullSignSettingsRow(
							title: "Clear Diagnostic Log",
							detail: "Remove all recorded signing events",
							systemImage: "trash",
							tint: NullSignStyle.warning,
							showsChevron: false
						)
					}
					.buttonStyle(.plain)
					.disabled(!_logExists)
					.opacity(_logExists ? 1 : 0.45)
				}

				NullSignSettingsSection("Verification Coverage") {
					_check("IPA structure and main executable", systemImage: "shippingbox")
					NullSignSettingsDivider()
					_check("Certificate, profile, and expiration", systemImage: "checkmark.seal")
					NullSignSettingsDivider()
					_check("Available storage and injection files", systemImage: "internaldrive")
					NullSignSettingsDivider()
					_check("Nested bundles and final signatures", systemImage: "square.stack.3d.up")
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 12)
			.padding(.bottom, 28)
		}
		.background(Color.black.ignoresSafeArea())
		.navigationTitle("Diagnostics")
		.onAppear(perform: _refresh)
	}

	private func _check(_ title: String, systemImage: String) -> some View {
		HStack(spacing: 12) {
			Image(systemName: systemImage)
				.font(.system(size: 15, weight: .semibold))
				.foregroundStyle(NullSignStyle.accent)
				.frame(width: 32, height: 32)
				.background(NullSignStyle.raisedPanel)
				.clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
			Text(title)
				.font(.body.weight(.medium))
			Spacer()
			Image(systemName: "checkmark")
				.font(.caption.weight(.bold))
				.foregroundStyle(NullSignStyle.accent)
		}
	}

	private func _refresh() {
		_logExists = FileManager.default.fileExists(atPath: ReliabilityCenter.shared.logURL.path)
	}
}
