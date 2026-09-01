import SwiftUI
import NimbleViews

struct CertificatesInfoView: View {
	@Environment(\.dismiss) private var dismiss
	@State private var data: Certificate?

	let cert: CertificatePair

	private var displayName: String {
		cert.nickname ?? data?.Name ?? "Certificate"
	}

	var body: some View {
		NBNavigationView("Certificate Info", displayMode: .inline) {
			ScrollView {
				VStack(spacing: 22) {
					NullSignSettingsIntro(
						systemImage: cert.revoked ? "xmark.shield.fill" : "checkmark.shield.fill",
						title: displayName,
						detail: data?.TeamName ?? "Reading provisioning profile…",
						status: cert.revoked ? "Revoked" : "Saved",
						statusColor: cert.revoked ? .red : NullSignStyle.cyan
					)

					if let data {
						NullSignSettingsSection("Status") {
							_infoRow("Expires", value: data.ExpirationDate.expirationInfo().formatted)
							NullSignSettingsDivider()
							_infoRow("Revocation", value: cert.revoked ? "Revoked" : "Not detected")
							if let ppq = data.PPQCheck {
								NullSignSettingsDivider()
								_infoRow("PPQ Check", value: ppq ? "Required" : "Not required")
							}
						}

						NullSignSettingsSection("Profile") {
							_infoRow("Name", value: data.Name)
							NullSignSettingsDivider()
							_infoRow("App ID", value: data.AppIDName)
							NullSignSettingsDivider()
							_infoRow("Team", value: data.TeamName)
							NullSignSettingsDivider()
							_infoRow("Platform", value: data.Platform.joined(separator: ", "))
							NullSignSettingsDivider()
							_infoRow("Team ID", value: data.TeamIdentifier.joined(separator: ", "))
							if let devices = data.ProvisionedDevices {
								NullSignSettingsDivider()
								_infoRow("Registered Devices", value: devices.count.description)
							}
						}

						if let entitlements = data.Entitlements {
							NullSignSettingsSection("Entitlements") {
								NavigationLink(destination: CertificatesInfoEntitlementView(entitlements: entitlements)) {
									NullSignSettingsRow(
										title: "View Entitlements",
										detail: "\(entitlements.count) keys",
										systemImage: "list.bullet.rectangle"
									)
								}
								.buttonStyle(.plain)
							}
						}
					}

					NullSignSettingsSection("Files") {
						Button {
							guard
								let directory = Storage.shared.getUuidDirectory(for: cert),
								let sharedURL = directory.toSharedDocumentsURL()
							else { return }
							UIApplication.open(sharedURL)
						} label: {
							NullSignSettingsRow(
								title: "Open in Files",
								detail: "View the saved certificate pair",
								systemImage: "folder"
							)
						}
						.buttonStyle(.plain)
					}
				}
				.padding(.horizontal, 16)
				.padding(.top, 12)
				.padding(.bottom, 28)
			}
			.background(Color.black.ignoresSafeArea())
			.toolbar {
				NBToolbarButton(role: .close)
			}
		}
		.onAppear {
			data = Storage.shared.getProvisionFileDecoded(for: cert)
		}
	}

	private func _infoRow(_ title: String, value: String) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: 16) {
			Text(title)
				.font(.body.weight(.medium))
			Spacer(minLength: 12)
			Text(value)
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.trailing)
				.copyableText(value)
		}
	}
}
