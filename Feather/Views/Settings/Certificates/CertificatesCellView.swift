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

		HStack(spacing: 12) {
			ZStack {
				NullSignRing(
					progress: validity.progress,
					size: 40,
					lineWidth: 3.5,
					tint: validity.tint == NullSignStyle.success ? .white : validity.tint
				)
				Text(validity.value)
					.font(.system(size: 12, weight: .bold, design: .rounded))
					.monospacedDigit()
					.minimumScaleFactor(0.6)
					.lineLimit(1)
					.frame(width: 28)
			}

			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.headline)
					.foregroundStyle(.white)
					.lineLimit(1)
				Text(subtitle)
					.font(.subheadline)
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)
				_status
					.padding(.top, 3)
			}

			Spacer(minLength: 4)

			if isSelected {
				Image(systemName: "checkmark")
					.font(.body.weight(.semibold))
					.foregroundStyle(NullSignStyle.accent)
					.accessibilityLabel("Selected")
			}
		}
		.contentTransition(.opacity)
		.task(id: cert.objectID) {
			data = await ProvisioningProfileCache.shared.profile(for: cert)
		}
	}

	@ViewBuilder
	private var _status: some View {
		HStack(spacing: 6) {
			if cert.revoked {
				Text("Revoked")
					.font(.caption.weight(.medium))
					.foregroundStyle(NullSignStyle.danger)
			} else if let expiration = cert.expiration {
				let label = NullSignValidity.shortLabel(for: expiration)
				Text(label.text)
					.font(.caption)
					.foregroundStyle(label.tint)
			}

			if cert.ppQCheck == true {
				NullSignChip(text: "PPQ")
			}

			if let platforms = data?.Platform, platforms.contains(where: { $0.localizedCaseInsensitiveContains("tvos") }) {
				NullSignChip(text: "tvOS", systemImage: "appletv.fill", tint: NullSignStyle.crimson, filled: true)
			}
		}
	}
}
