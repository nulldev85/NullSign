import SwiftUI
import NimbleViews

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

	var body: some View {
		NBNavigationView("Settings") {
			Form {
				NBSection("Signing Certificates") {
					if let certificate = selectedCertificate {
						CertificatesCellView(cert: certificate)
					} else {
						Label("No certificate selected", systemImage: "exclamationmark.triangle")
							.foregroundStyle(.secondary)
					}

					NavigationLink(destination: CertificatesView()) {
						Label("Import & Manage Certificates", systemImage: "checkmark.seal")
					}
				} footer: {
					Text("Import a .p12 and matching .mobileprovision, choose the active certificate, rename saved certificates, or remove expired credentials.")
				}

				NBSection("Installation") {
					NavigationLink(destination: InstallationView()) {
						Label("Installation Method", systemImage: "arrow.down.app")
					}
				} footer: {
					Text("Choose how NullSign installs apps after signing.")
				}

				NBSection("Signing") {
					NavigationLink(destination: ConfigurationView()) {
						Label("Signing Defaults & Advanced Options", systemImage: "signature")
					}
				} footer: {
					Text("Set defaults for app signing, injection, ElleKit, and post-signing behavior.")
				}

				NBSection("Reliability") {
					NavigationLink(destination: DiagnosticsView()) {
						Label("Diagnostics", systemImage: "stethoscope")
					}
				} footer: {
					Text("Review NullSign's local checks or export a privacy-safe log when an app will not sign.")
				}

				Section("NullSign") {
					LabeledContent("Theme", value: "OLED Black / Cyan")
					LabeledContent("Version", value: Bundle.main.version)
					NavigationLink(destination: ResetView()) {
						Label("Reset Local Data", systemImage: "trash")
					}
				}
			}
			.scrollContentBackground(.hidden)
			.background(Color.black)
		}
	}
}
