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
		let validity = NullSignValidity(certificate: cert, profile: data)

		HStack(spacing: 14) {
			ZStack {
				NullSignRing(
					progress: validity.progress,
					size: 44,
					lineWidth: 4.5,
					tint: validity.tint,
					showsSignalDot: isSelected
				)
				Image(systemName: cert.revoked ? "xmark" : "checkmark.seal.fill")
					.font(.system(size: 14, weight: .bold))
					.foregroundStyle(cert.revoked ? NullSignStyle.danger : Color.white)
			}

			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.font(.system(size: 16, weight: .semibold))
					.foregroundStyle(.white)
					.lineLimit(1)
				Text(subtitle)
					.font(NullSignStyle.mono(11, weight: .medium))
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)
				_status(validity)
			}

			Spacer(minLength: 4)

			if isSelected {
				NullSignChip(text: "Active", systemImage: "checkmark", tint: NullSignStyle.accent, filled: true)
					.accessibilityLabel("Selected")
			}
		}
		.contentTransition(.opacity)
		.task(id: cert.objectID) {
			data = await ProvisioningProfileCache.shared.profile(for: cert)
		}
	}

	@ViewBuilder
	private func _status(_ validity: NullSignValidity) -> some View {
		HStack(spacing: 5) {
			if cert.revoked {
				NullSignChip(text: "Revoked", systemImage: "xmark", tint: NullSignStyle.danger)
			} else if let expiration = cert.expiration {
				let label = NullSignValidity.shortLabel(for: expiration)
				NullSignChip(text: label.text, systemImage: "clock", tint: label.tint)
			}

			if cert.ppQCheck == true {
				NullSignChip(text: "PPQ", tint: NullSignStyle.muted)
			}

			if let platforms = data?.Platform, platforms.contains(where: { $0.localizedCaseInsensitiveContains("tvos") }) {
				NullSignChip(text: "tvOS", systemImage: "appletv.fill", tint: NullSignStyle.crimson, uppercased: false)
			}
		}
	}
}
