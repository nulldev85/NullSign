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
		.padding(14)
		.nullSignSurface(cornerRadius: 22)
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
				.padding(.horizontal, 6)

			// A section can be a note only (an empty body); skip the empty card.
			if Content.self != EmptyView.self {
				NullSignSettingsCard { content }
			}

			if let detail {
				Text(detail)
					.font(.footnote)
					.foregroundStyle(NullSignStyle.muted)
					.fixedSize(horizontal: false, vertical: true)
					.padding(.horizontal, 6)
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
						.tint(tint)
						.frame(width: 34, height: 34)
						.background(
							RoundedRectangle(cornerRadius: 10.5, style: .continuous)
								.fill(tint.opacity(0.12))
						)
				} else {
					NullSignIconTile(systemImage: systemImage, tint: tint, size: 34)
				}
			}

			VStack(alignment: .leading, spacing: detail == nil ? 0 : 2) {
				Text(title)
					.font(.system(size: 16, weight: .semibold))
					.foregroundStyle(.white)
				if let detail {
					Text(detail)
						.font(.caption)
						.foregroundStyle(NullSignStyle.muted)
						.fixedSize(horizontal: false, vertical: true)
				}
			}

			Spacer(minLength: 8)

			if let value {
				Text(value)
					.font(NullSignStyle.mono(13, weight: .semibold))
					.foregroundStyle(NullSignStyle.muted)
			}
			if showsChevron {
				Image(systemName: "chevron.right")
					.font(.system(size: 12, weight: .bold))
					.foregroundStyle(NullSignStyle.faint)
			}
		}
		.frame(minHeight: 44)
		.contentShape(Rectangle())
	}
}

struct NullSignSettingsDivider: View {
	var body: some View {
		Rectangle()
			.fill(NullSignStyle.hairline)
			.frame(height: 1)
			.padding(.leading, 46)
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
		HStack(alignment: .top, spacing: 14) {
			NullSignIconTile(systemImage: systemImage, tint: .white, size: 46)

			VStack(alignment: .leading, spacing: 7) {
				HStack(alignment: .firstTextBaseline, spacing: 8) {
					Text(title)
						.font(NullSignStyle.display(17, weight: .bold))
						.lineLimit(2)
					Spacer(minLength: 8)
					if let status {
						NullSignChip(text: status, tint: statusColor)
					}
				}
				Text(detail)
					.font(.subheadline)
					.foregroundStyle(NullSignStyle.muted)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.padding(18)
		.background(
			RadialGradient(
				colors: [NullSignStyle.accent.opacity(0.18), .clear],
				center: .topLeading,
				startRadius: 2,
				endRadius: 260
			)
		)
		.nullSignSurface(cornerRadius: 24)
	}
}

/// A large launcher tile for the settings grid.
private struct NullSignSettingsTile: View {
	let systemImage: String
	let title: String
	let detail: String
	let tint: Color

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			HStack(alignment: .top) {
				NullSignIconTile(systemImage: systemImage, tint: tint, size: 40)
				Spacer()
				Image(systemName: "arrow.up.right")
					.font(.system(size: 12, weight: .bold))
					.foregroundStyle(NullSignStyle.faint)
			}
			Spacer(minLength: 20)
			Text(title)
				.font(.system(size: 16, weight: .bold))
				.foregroundStyle(.white)
				.lineLimit(1)
			Text(detail)
				.font(NullSignStyle.mono(10.5, weight: .medium))
				.foregroundStyle(NullSignStyle.muted)
				.lineLimit(1)
				.padding(.top, 3)
		}
		.padding(15)
		.frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
		.background(
			RadialGradient(
				colors: [tint.opacity(0.17), .clear],
				center: .topLeading,
				startRadius: 2,
				endRadius: 160
			)
		)
		.nullSignSurface(cornerRadius: 22)
		.contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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

	private var versionLabel: String {
		"Version \(Bundle.main.version) · Build \(_build)"
	}

	private let _columns = [
		GridItem(.flexible(), spacing: 12),
		GridItem(.flexible(), spacing: 12)
	]

	var body: some View {
		NBNavigationView("", displayMode: .inline) {
			ScrollView {
				VStack(spacing: 22) {
					NullSignTitle(title: "Settings", subtitle: "NullSign \(Bundle.main.version) · build \(_build)")
						.padding(.horizontal, 4)

					NullSignIdentityCard(certificate: NullSignIdentity.activeCertificate(in: certificates)) {
						_isCertificatesPresenting = true
					}

					LazyVGrid(columns: _columns, spacing: 12) {
						NavigationLink {
							CertificatesView()
						} label: {
							NullSignSettingsTile(
								systemImage: "checkmark.seal.fill",
								title: "Certificates",
								detail: certificates.count == 1 ? "1 identity" : "\(certificates.count) identities",
								tint: NullSignStyle.accentHighlight
							)
						}
						.buttonStyle(NullSignPressableStyle())

						NavigationLink {
							ConfigurationView()
						} label: {
							NullSignSettingsTile(
								systemImage: "signature",
								title: "Signing",
								detail: "Defaults & rules",
								tint: NullSignStyle.violet
							)
						}
						.buttonStyle(NullSignPressableStyle())

						NavigationLink {
							InstallationView()
						} label: {
							NullSignSettingsTile(
								systemImage: _installationMethod == 0 ? "iphone.and.arrow.forward" : "appletv.fill",
								title: "Install",
								detail: _installationMethod == 0 ? "iPhone · local" : "Apple TV · tunnel",
								tint: NullSignStyle.success
							)
						}
						.buttonStyle(NullSignPressableStyle())

						NavigationLink {
							DiagnosticsView()
						} label: {
							NullSignSettingsTile(
								systemImage: "waveform.path.ecg",
								title: "Diagnostics",
								detail: "Signing log",
								tint: NullSignStyle.warning
							)
						}
						.buttonStyle(NullSignPressableStyle())
					}

					NullSignSettingsSection("System") {
						NavigationLink(destination: ResetView()) {
							NullSignSettingsRow(
								title: "Storage & Reset",
								detail: "Clear caches or remove local NullSign data",
								systemImage: "internaldrive",
								tint: NullSignStyle.warning
							)
						}
						.buttonStyle(.plain)

						NullSignSettingsDivider()

						NavigationLink(destination: AboutView()) {
							NullSignSettingsRow(
								title: "About NullSign",
								detail: versionLabel,
								systemImage: "info.circle"
							)
						}
						.buttonStyle(.plain)
					}

					HStack(spacing: 7) {
						Circle()
							.fill(NullSignStyle.accent)
							.frame(width: 5, height: 5)
						Text("SIGNED ON YOUR DEVICE. YOUR KEYS STAY HERE.")
							.font(NullSignStyle.mono(10, weight: .semibold))
							.tracking(0.8)
							.foregroundStyle(NullSignStyle.faint)
					}
					.padding(.top, 4)
					.padding(.bottom, 12)
				}
				.padding(.horizontal, 16)
				.padding(.top, 4)
				.padding(.bottom, 24)
			}
			.background(NullSignBackdrop())
			.navigationDestination(isPresented: $_isCertificatesPresenting) {
				CertificatesView()
			}
		}
	}
}
