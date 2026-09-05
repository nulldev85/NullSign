import SwiftUI

struct CertificatesCellView: View {
	@State private var data: Certificate?
	@ObservedObject var cert: CertificatePair
	var isSelected = false

	private var title: String {
		cert.nickname ?? data?.Name ?? "Unknown certificate"
	}

	private var subtitle: String {
		if let teamName = data?.TeamName, !teamName.isEmpty { return teamName }
		return data?.AppIDName ?? "Provisioning profile unavailable"
	}

	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: cert.revoked ? "xmark.shield.fill" : "checkmark.shield.fill")
				.font(.system(size: 18, weight: .medium))
				.foregroundStyle(cert.revoked ? NullSignStyle.warning : NullSignStyle.accent)
				.frame(width: 38, height: 38)
				.background(NullSignStyle.raisedPanel)
				.clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

			VStack(alignment: .leading, spacing: 3) {
				Text(title)
					.font(.body.weight(.semibold))
					.foregroundStyle(.primary)
					.lineLimit(1)
				Text(subtitle)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
				_status
			}

			Spacer(minLength: 4)

			if isSelected {
				Image(systemName: "checkmark.circle.fill")
					.font(.body)
					.foregroundStyle(NullSignStyle.accent)
					.accessibilityLabel("Selected")
			}
		}
		.contentTransition(.opacity)
		.onAppear {
			data = Storage.shared.getProvisionFileDecoded(for: cert)
		}
	}

	@ViewBuilder
	private var _status: some View {
		HStack(spacing: 8) {
			if cert.revoked {
				_statusText("Revoked", color: NullSignStyle.warning)
			} else if let expiration = cert.expiration {
				let info = expiration.expirationInfo()
				_statusText(info.formatted, color: info.color)
			}

			if cert.ppQCheck == true {
				_statusText("PPQ", color: NullSignStyle.muted)
			}
		}
	}

	private func _statusText(_ text: String, color: Color) -> some View {
		HStack(spacing: 4) {
			Circle()
				.fill(color)
				.frame(width: 5, height: 5)
			Text(text)
		}
		.font(.caption2.weight(.medium))
		.foregroundStyle(.secondary)
	}
}
