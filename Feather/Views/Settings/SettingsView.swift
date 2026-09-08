import SwiftUI
import NimbleViews

struct NullSignSettingsCard<Content: View>: View {
	private let content: Content

	init(@ViewBuilder content: () -> Content) {
		self.content = content()
	}

	var body: some View {
		VStack(spacing: 0) {
			content
		}
		.padding(14)
		.nullSignSurface(cornerRadius: 18)
	}
}

struct NullSignSettingsSection<Content: View>: View {
	let title: String
	let detail: String?
	private let content: Content

	init(_ title: String, detail: String? = nil, @ViewBuilder content: () -> Content) {
		self.title = title
		self.detail = detail
		self.content = content()
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 9) {
			Text(title)
				.font(.caption.weight(.semibold))
				.tracking(0.6)
				.foregroundStyle(.secondary)

			NullSignSettingsCard { content }

			if let detail {
				Text(detail)
					.font(.footnote)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
					.padding(.horizontal, 4)
			}
		}
	}
}

struct NullSignSettingsRow: View {
	let title: String
	let detail: String?
	let systemImage: String
	var value: String? = nil
	var tint: Color = NullSignStyle.accent
	var showsChevron = true

	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: systemImage)
				.font(.system(size: 15, weight: .semibold))
				.foregroundStyle(tint)
				.frame(width: 32, height: 32)
				.background(NullSignStyle.raisedPanel)
				.clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

			VStack(alignment: .leading, spacing: detail == nil ? 0 : 2) {
				Text(title)
					.font(.body.weight(.medium))
					.foregroundStyle(.primary)
				if let detail {
					Text(detail)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}
			}

			Spacer(minLength: 8)

			if let value {
				Text(value)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
			if showsChevron {
				Image(systemName: "chevron.right")
					.font(.caption.weight(.semibold))
					.foregroundStyle(.tertiary)
			}
		}
		.contentShape(Rectangle())
	}
}

struct NullSignSettingsDivider: View {
	var body: some View {
		Divider()
			.overlay(NullSignStyle.hairline)
			.padding(.leading, 44)
			.padding(.vertical, 10)
	}
}

struct NullSignSettingsIntro: View {
	let systemImage: String
	let title: String
	let detail: String
	var status: String? = nil
	var statusColor: Color = NullSignStyle.accent

	var body: some View {
		NullSignSettingsCard {
			HStack(alignment: .top, spacing: 14) {
				Image(systemName: systemImage)
					.font(.system(size: 22, weight: .medium))
					.foregroundStyle(NullSignStyle.accent)
					.frame(width: 42, height: 42)
					.background(NullSignStyle.raisedPanel)
					.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

				VStack(alignment: .leading, spacing: 4) {
					HStack(alignment: .firstTextBaseline) {
						Text(title)
							.font(.headline)
						Spacer(minLength: 8)
						if let status {
							Text(status)
								.font(.caption.weight(.semibold))
								.foregroundStyle(statusColor)
						}
					}
					Text(detail)
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}
			}
		}
	}
}

struct SettingsView: View {
	@AppStorage("feather.selectedCert") private var selectedCertificateIndex = 0

	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var certificates: FetchedResults<CertificatePair>

	private var selectedCertificate: CertificatePair? {
		guard certificates.indices.contains(selectedCertificateIndex) else { return nil }
		return certificates[selectedCertificateIndex]
	}

	private var identityTitle: String {
		selectedCertificate?.nickname ?? (selectedCertificate == nil ? "No certificate selected" : "Signing certificate")
	}

	private var identityDetail: String {
		guard let certificate = selectedCertificate else {
			return "Import a certificate and provisioning profile before signing."
		}
		guard let expiration = certificate.expiration else { return "Ready for signing" }
		return "Expires \(expiration.formatted(date: .abbreviated, time: .omitted))"
	}

	private var versionLabel: String {
		let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
		return "Version \(Bundle.main.version) · Build \(build)"
	}

	var body: some View {
		NBNavigationView("Settings") {
			ScrollView {
				LazyVStack(spacing: 24) {
					NullSignSettingsIntro(
						systemImage: selectedCertificate == nil ? "seal" : "checkmark.seal.fill",
						title: identityTitle,
						detail: identityDetail,
						status: selectedCertificate == nil ? "Setup needed" : "Active",
						statusColor: selectedCertificate == nil ? NullSignStyle.warning : NullSignStyle.accent
					)

					NullSignSettingsSection("Signing") {
						NavigationLink(destination: CertificatesView()) {
							NullSignSettingsRow(
								title: "Certificates",
								detail: "Import, select, rename, and inspect identities",
								systemImage: "checkmark.seal"
							)
						}
						.buttonStyle(.plain)

						NullSignSettingsDivider()

						NavigationLink(destination: ConfigurationView()) {
							NullSignSettingsRow(
								title: "Signing Defaults",
								detail: "Names, identifiers, injection, and post-signing behavior",
								systemImage: "signature"
							)
						}
						.buttonStyle(.plain)
					}

					NullSignSettingsSection("Installation") {
						NavigationLink(destination: InstallationView()) {
							NullSignSettingsRow(
								title: "Installation Method",
								detail: "Choose the route used to deliver signed apps",
								systemImage: "iphone.and.arrow.forward"
							)
						}
						.buttonStyle(.plain)
					}

					NullSignSettingsSection("Maintenance") {
						NavigationLink(destination: DiagnosticsView()) {
							NullSignSettingsRow(
								title: "Diagnostics",
								detail: "Review checks and export the local signing log",
								systemImage: "waveform.path.ecg"
							)
						}
						.buttonStyle(.plain)

						NullSignSettingsDivider()

						NavigationLink(destination: ResetView()) {
							NullSignSettingsRow(
								title: "Storage & Reset",
								detail: "Clear caches or remove local NullSign data",
								systemImage: "internaldrive",
								tint: NullSignStyle.warning
							)
						}
						.buttonStyle(.plain)
					}

					NullSignSettingsSection("NullSign") {
						NavigationLink(destination: AboutView()) {
							NullSignSettingsRow(
								title: "About NullSign",
								detail: versionLabel,
								systemImage: "info.circle"
							)
						}
						.buttonStyle(.plain)
					}

					Text("Signed on your device. Your keys stay here.")
						.font(.caption)
						.foregroundStyle(.secondary)
						.padding(.top, 2)
						.padding(.bottom, 18)
				}
				.padding(.horizontal, 16)
				.padding(.top, 12)
			}
			.scrollContentBackground(.hidden)
			.background(Color.black.ignoresSafeArea())
		}
	}
}
