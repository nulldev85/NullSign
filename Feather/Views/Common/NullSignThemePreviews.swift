#if DEBUG
import SwiftUI

/// Isolated previews use the real shared components without loading repositories or signing files.
private struct NullSignDashboardThemePreview: View {
	@State private var search = ""
	@State private var scope = 0

	var body: some View {
		ScrollView {
			VStack(spacing: 0) {
				NullSignOverviewBanner(
					title: "On this device",
					value: "2",
					detail: "1 signed · 1 imported",
					systemImage: "checkmark.seal.fill"
				)
				VStack(spacing: 14) {
					NullSignSearchField(prompt: "Search", text: $search)
					NullSignSegmentedControl(
						options: [0, 1, 2], selection: $scope,
						title: { ["All", "Signed", "Imported"][$0] },
						count: { $0 == 0 ? nil : 1 }
					)
					NullSignSectionLabel(title: "Signed", count: 1, prominent: true, systemImage: "checkmark.seal")
					appRow(action: "Install", primary: true)
					NullSignSectionLabel(title: "Imported", count: 1, prominent: true, systemImage: "tray.and.arrow.down")
					appRow(action: "Sign", primary: false)
					NullSignSectionLabel(title: "Actions", prominent: true)
					HStack {
						Button("Copy") { }
							.buttonStyle(NullSignSecondaryButtonStyle(height: 36))
						Button("Delete") { }
							.buttonStyle(NullSignPrimaryButtonStyle(height: 36, tint: NullSignStyle.danger))
					}
				}
				.padding(.horizontal, 20)
				.padding(.bottom, 28)
			}
		}
		.background(NullSignStyle.ink)
		.environment(\.font, .roundedUI(.body))
		.preferredColorScheme(.dark)
	}

	private func appRow(action: String, primary: Bool) -> some View {
		HStack(spacing: 12) {
			Image("LineupTV")
				.resizable()
				.scaledToFit()
				.frame(width: 56, height: 56)
				.background(NullSignStyle.raisedPanel)
				.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
			VStack(alignment: .leading, spacing: 3) {
				Text("Lineup").font(.roundedUI(.headline)).lineLimit(1)
				Text("com.nulldev85.NullSports")
					.font(.roundedUI(.subheadline))
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)
				PlatformBadge(platform: .tvOS)
			}
			Spacer(minLength: 4)
			if primary {
				Button(action) { }.buttonStyle(NullSignPrimaryButtonStyle(height: 32))
			} else {
				Button(action) { }.buttonStyle(NullSignSecondaryButtonStyle(height: 32))
			}
		}
		.padding(14)
		.nullSignSurface()
	}
}

private struct NullSignSettingsThemePreview: View {
	var body: some View {
		ScrollView {
			VStack(spacing: 28) {
				NullSignSettingsIntro(
					systemImage: "checkmark.seal",
					title: "Signing Certificates",
					detail: "A certificate and provisioning profile are ready for signing.",
					status: "Active", statusColor: NullSignStyle.success
				)
				NullSignSettingsSection("Signing") {
					NullSignSettingsRow(title: "Certificates", detail: nil, systemImage: "checkmark.seal", value: "1")
					NullSignSettingsDivider()
					NullSignSettingsRow(title: "Signing Defaults", detail: nil, systemImage: "signature")
				}
				NullSignSettingsSection("Installation") {
					NullSignSettingsRow(title: "Installation Method", detail: nil, systemImage: "arrow.down.app", value: "Apple TV")
				}
				NullSignSettingsSection("Maintenance") {
					NullSignSettingsRow(title: "Diagnostics", detail: nil, systemImage: "waveform.path.ecg")
					NullSignSettingsDivider()
					NullSignSettingsRow(title: "Storage & Reset", detail: nil, systemImage: "internaldrive")
				}
				NullSignSettingsSection("About") {
					NullSignSettingsRow(title: "About NullSign", detail: nil, systemImage: "info.circle", value: "1.0 (123)")
				}
			}
			.padding(20)
		}
		.background(NullSignStyle.canvas)
		.environment(\.font, .roundedUI(.body))
		.preferredColorScheme(.dark)
	}
}

struct NullSignThemePreviews: PreviewProvider {
	static var previews: some View {
		Group {
			NullSignDashboardThemePreview()
				.previewLayout(.fixed(width: 390, height: 844))
				.previewDisplayName("Dashboard · standard")
			NullSignDashboardThemePreview()
				.previewLayout(.fixed(width: 320, height: 667))
				.previewDisplayName("Dashboard · small phone")
			NullSignSettingsThemePreview()
				.previewLayout(.fixed(width: 390, height: 844))
				.previewDisplayName("Settings · standard")
			NullSignSettingsThemePreview()
				.environment(\.dynamicTypeSize, .accessibility1)
				.previewLayout(.fixed(width: 320, height: 844))
				.previewDisplayName("Settings · accessibility text")
			NullSignMenuSheet(title: "Import", systemImage: "tray.and.arrow.down", detail: "Choose how to add an app to your signing library.") {
				NullSignSettingsCard {
					NullSignMenuAction(title: "Import from Files", systemImage: "folder.fill", detail: "Choose one or more IPA or TIPA files.", tint: NullSignStyle.warning) { }
					NullSignSettingsDivider()
					NullSignMenuAction(title: "Import from URL", systemImage: "link", detail: "Download an app from a direct link.") { }
				}
			}
			.previewLayout(.fixed(width: 390, height: 500))
			.previewDisplayName("Import choices · menu")
			ImportURLView { _ in }
				.previewLayout(.fixed(width: 390, height: 844))
				.previewDisplayName("Import URL · standard")
			ImportURLView { _ in }
				.environment(\.dynamicTypeSize, .accessibility1)
				.previewLayout(.fixed(width: 320, height: 844))
				.previewDisplayName("Import URL · accessibility text")
		}
	}
}
#endif
