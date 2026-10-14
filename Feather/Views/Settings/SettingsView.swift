import SwiftUI
import NimbleViews

// MARK: - Shared Settings Components

struct NullSignSettingsCard<Content: View>: View {
	private let content: Content

	init(@ViewBuilder content: () -> Content) {
		self.content = content()
	}

	var body: some View {
		VStack(spacing: 0) {
			content
		}
		.padding(.horizontal, 18)
		.padding(.vertical, 8)
		.nullSignSurface(fill: NullSignStyle.groupedSurface)
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
		VStack(alignment: .leading, spacing: 10) {
			NullSignSectionLabel(title: title)
				.padding(.horizontal, 4)

			// A section can be a note only (an empty body); skip the empty card.
			if Content.self != EmptyView.self {
				NullSignSettingsCard { content }
			}

			if let detail {
				Text(detail)
					.font(.roundedUI(.footnote))
					.foregroundStyle(NullSignStyle.faint)
					.fixedSize(horizontal: false, vertical: true)
					.padding(.horizontal, 4)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

struct NullSignSettingsRow: View {
	let title: String
	let detail: String?
	let systemImage: String
	var value: String? = nil
	var tint: Color = .white
	var showsChevron = true
	var isBusy = false

	var body: some View {
		HStack(alignment: .center, spacing: 12) {
			Group {
				if isBusy {
					ProgressView()
						.controlSize(.small)
						.frame(width: 32, height: 32)
				} else {
					NullSignIconTile(
						systemImage: systemImage,
						tint: tint == .white ? NullSignStyle.categoryColor(for: systemImage) : tint,
						size: 32,
						filled: true
					)
				}
			}

			VStack(alignment: .leading, spacing: detail == nil ? 0 : 2) {
				Text(title)
					.font(.roundedUI(.body, weight: .bold))
					.foregroundStyle(.white)
				if let detail {
					Text(detail)
						.font(.roundedUI(.footnote))
						.foregroundStyle(NullSignStyle.muted)
						.fixedSize(horizontal: false, vertical: true)
				}
			}

			Spacer(minLength: 8)

			if let value {
				Text(value)
					.font(.roundedUI(.subheadline, weight: .bold))
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)
					.minimumScaleFactor(0.8)
					.layoutPriority(-1)
			}
			if showsChevron {
				Image(systemName: "chevron.right")
					.font(.roundedUI(.footnote, weight: .semibold))
					.foregroundStyle(NullSignStyle.faint)
			}
		}
		.frame(minHeight: 52)
		.contentShape(Rectangle())
	}
}

struct NullSignSettingsDivider: View {
	var body: some View {
		Rectangle()
			.fill(NullSignStyle.hairline)
			.frame(height: 1)
			.padding(.leading, 44)
			.padding(.vertical, 2)
	}
}

struct NullSignSettingsIntro: View {
	let systemImage: String
	let title: String
	let detail: String
	var status: String? = nil
	var statusColor: Color = NullSignStyle.accent

	var body: some View {
		HStack(alignment: .top, spacing: 14) {
			NullSignIconTile(systemImage: systemImage, tint: NullSignStyle.categoryColor(for: systemImage), size: 40, filled: true)

			VStack(alignment: .leading, spacing: 4) {
				HStack(alignment: .firstTextBaseline, spacing: 8) {
					Text(title)
						.font(.roundedUI(.headline))
						.lineLimit(2)
					Spacer(minLength: 8)
					if let status {
						Text(status)
							.font(.roundedUI(.footnote, weight: .bold))
							.foregroundStyle(statusColor)
					}
				}
				Text(detail)
					.font(.roundedUI(.subheadline))
					.foregroundStyle(NullSignStyle.muted)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.padding(18)
		.nullSignSurface(fill: NullSignStyle.groupedSurface)
	}
}

// MARK: - Settings

struct SettingsView: View {
	@AppStorage("Feather.installationMethod") private var _installationMethod = 0
	@State private var _isCertificatesPresenting = false

	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var certificates: FetchedResults<CertificatePair>

	private var _build: String {
		Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
	}

	var body: some View {
		NBNavigationView("Settings", displayMode: .inline) {
			ScrollView {
				VStack(spacing: 28) {
					NullSignIdentityCard(certificate: NullSignIdentity.activeCertificate(in: certificates)) {
						_isCertificatesPresenting = true
					}

					NullSignSettingsSection("Signing") {
						NavigationLink(destination: CertificatesView()) {
							NullSignSettingsRow(
								title: "Certificates",
								detail: nil,
								systemImage: "checkmark.seal",
								value: certificates.count.description
							)
						}
						.buttonStyle(.plain)

						NullSignSettingsDivider()

						NavigationLink(destination: ConfigurationView()) {
							NullSignSettingsRow(
								title: "Signing Defaults",
								detail: nil,
								systemImage: "signature"
							)
						}
						.buttonStyle(.plain)
					}

					NullSignSettingsSection("Installation") {
						NavigationLink(destination: InstallationView()) {
							NullSignSettingsRow(
								title: "Installation Method",
								detail: nil,
								systemImage: "arrow.down.app",
								value: _installationMethod == 0 ? "iPhone" : "Apple TV"
							)
						}
						.buttonStyle(.plain)
					}

					NullSignSettingsSection("Maintenance") {
						NavigationLink(destination: DiagnosticsView()) {
							NullSignSettingsRow(
								title: "Diagnostics",
								detail: nil,
								systemImage: "waveform.path.ecg"
							)
						}
						.buttonStyle(.plain)

						NullSignSettingsDivider()

						NavigationLink(destination: ResetView()) {
							NullSignSettingsRow(
								title: "Storage & Reset",
								detail: nil,
								systemImage: "internaldrive"
							)
						}
						.buttonStyle(.plain)
					}

					NullSignSettingsSection("About") {
						NavigationLink(destination: AboutView()) {
							NullSignSettingsRow(
								title: "About NullSign",
								detail: nil,
								systemImage: "info.circle",
								value: "\(Bundle.main.version) (\(_build))"
							)
						}
						.buttonStyle(.plain)
					}

					Text("Apps are signed on this device. Certificates and passwords never leave it.")
						.font(.roundedUI(.footnote))
						.foregroundStyle(NullSignStyle.faint)
						.multilineTextAlignment(.center)
						.padding(.horizontal, 24)
						.padding(.bottom, 12)
				}
				.padding(.horizontal, 20)
				.padding(.top, 12)
				.padding(.bottom, 24)
			}
			.background(NullSignStyle.canvas)
			.toolbarBackground(NullSignStyle.canvas, for: .navigationBar)
			.toolbarBackground(.visible, for: .navigationBar)
			.navigationDestination(isPresented: $_isCertificatesPresenting) {
				CertificatesView()
			}
		}
	}
}
